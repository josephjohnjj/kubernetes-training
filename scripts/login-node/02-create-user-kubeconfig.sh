#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/login-node/02-create-user-kubeconfig.sh <username>

Example:
  ./scripts/login-node/02-create-user-kubeconfig.sh mluser1

Run this script on the login node as the Kubernetes administrator account
(currently ubuntu). The script creates a persistent ServiceAccount token and
installs a restricted kubeconfig in the matching Linux user's home directory.
EOF
}

if [[ $# -ne 1 ]]; then
  usage >&2
  exit 2
fi

if [[ $EUID -eq 0 ]]; then
  echo "Do not run this script with sudo." >&2
  echo "Run it as the account whose kubeconfig has cluster-admin access." >&2
  exit 1
fi

username=$1
namespace=mlproject
role_name=kubeflow-cpu-job-submitter
secret_name="${username}-token"

if [[ ! $username =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
  echo "Invalid username: $username" >&2
  echo "Use a lowercase Linux username of at most 32 characters." >&2
  exit 2
fi

for command_name in base64 getent grep kubectl mktemp seq sudo; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Required command not found: $command_name" >&2
    exit 1
  fi
done

if ! id "$username" >/dev/null 2>&1; then
  echo "Linux user does not exist: $username" >&2
  exit 1
fi

user_home=$(getent passwd "$username" | cut -d: -f6)
user_group=$(id -gn "$username")

if [[ -z $user_home || $user_home == / ]]; then
  echo "Could not determine a safe home directory for $username" >&2
  exit 1
fi

if ! kubectl auth can-i create secrets --namespace="$namespace" | grep -qx yes; then
  echo "The current kubeconfig cannot create Secrets in $namespace." >&2
  echo "Run this script as the login-node Kubernetes administrator." >&2
  exit 1
fi

if ! kubectl -n "$namespace" get serviceaccount "$username" >/dev/null 2>&1; then
  echo "ServiceAccount $namespace:$username does not exist." >&2
  echo "Commit the user's Argo CD manifest and wait for synchronization first." >&2
  exit 1
fi

if ! kubectl -n "$namespace" get role "$role_name" >/dev/null 2>&1; then
  echo "Required Role $namespace:$role_name does not exist." >&2
  exit 1
fi

if ! kubectl -n "$namespace" get rolebinding \
  "${username}-kubeflow-submitter" >/dev/null 2>&1; then
  echo "Required RoleBinding ${username}-kubeflow-submitter does not exist." >&2
  exit 1
fi

kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: ${secret_name}
  namespace: ${namespace}
  annotations:
    kubernetes.io/service-account.name: ${username}
type: kubernetes.io/service-account-token
EOF

echo "Waiting for Kubernetes to populate $namespace/$secret_name."
for _ in $(seq 1 30); do
  token_data=$(kubectl -n "$namespace" get secret "$secret_name" \
    -o jsonpath='{.data.token}' 2>/dev/null || true)
  ca_data=$(kubectl -n "$namespace" get secret "$secret_name" \
    -o jsonpath='{.data.ca\.crt}' 2>/dev/null || true)
  if [[ -n $token_data && -n $ca_data ]]; then
    break
  fi
  sleep 1
done

if [[ -z ${token_data:-} || -z ${ca_data:-} ]]; then
  echo "Timed out waiting for the ServiceAccount token Secret." >&2
  exit 1
fi

server=$(kubectl config view --minify --raw \
  -o jsonpath='{.clusters[0].cluster.server}')
token=$(printf '%s' "$token_data" | base64 --decode)

if [[ -z $server || -z $token ]]; then
  echo "Could not obtain the API server or ServiceAccount token." >&2
  exit 1
fi

umask 077
temporary_kubeconfig=$(mktemp /tmp/user-kubeconfig.XXXXXX)
trap 'rm -f "$temporary_kubeconfig"' EXIT

cat > "$temporary_kubeconfig" <<EOF
apiVersion: v1
kind: Config
clusters:
  - name: training-cluster
    cluster:
      server: ${server}
      certificate-authority-data: ${ca_data}
contexts:
  - name: mlproject
    context:
      cluster: training-cluster
      namespace: ${namespace}
      user: ${username}
current-context: mlproject
users:
  - name: ${username}
    user:
      token: ${token}
EOF

unset token token_data ca_data

sudo install -d -o "$username" -g "$user_group" -m 0700 "$user_home/.kube"
sudo install -o "$username" -g "$user_group" -m 0600 \
  "$temporary_kubeconfig" "$user_home/.kube/config"

echo
echo "Installed restricted kubeconfig: $user_home/.kube/config"
echo "Kubernetes identity: system:serviceaccount:$namespace:$username"
echo
echo "Test it with:"
echo "  sudo -u '$username' kubectl auth whoami"
echo "  sudo -u '$username' kubectl auth can-i create trainjobs.trainer.kubeflow.org"
echo "  sudo -u '$username' kubectl auth can-i create pods"
echo "  sudo -u '$username' kubectl auth can-i get secrets"
echo
echo "Delete secret/$secret_name immediately if the kubeconfig is exposed."
