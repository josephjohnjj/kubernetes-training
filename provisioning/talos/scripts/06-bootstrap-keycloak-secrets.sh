#!/usr/bin/env bash
set -Eeuo pipefail

# Bootstrap credentials that must exist before CNPG reconciles the Keycloak
# role and before Argo CD performs Keycloak's initial sync. Secret values are
# applied to the cluster only; they are never written into the repository.

for required_command in kubectl; do
  if ! command -v "${required_command}" >/dev/null 2>&1; then
    echo "Required command not found: ${required_command}" >&2
    exit 1
  fi
done

temporary_directory=$(mktemp -d)
cleanup() {
  rm -f \
    "${temporary_directory}/username" \
    "${temporary_directory}/password" \
    "${temporary_directory}/db-password" \
    "${temporary_directory}/admin-password"
  rmdir "${temporary_directory}"
}
trap cleanup EXIT
chmod 700 "${temporary_directory}"

secret_exists() {
  local namespace=$1
  local name=$2
  kubectl get secret "${name}" --namespace "${namespace}" >/dev/null 2>&1
}

read_secret_key() {
  local namespace=$1
  local name=$2
  local key=$3
  kubectl get secret "${name}" --namespace "${namespace}" \
    --output "go-template={{ index .data \"${key}\" | base64decode }}"
}

prompt_password() {
  local prompt=$1
  local first_password
  local second_password

  read -r -s -p "${prompt}: " first_password
  echo
  read -r -s -p "Confirm ${prompt}: " second_password
  echo

  if [[ -z "${first_password}" ]]; then
    echo "Password must not be empty." >&2
    exit 1
  fi
  if [[ "${first_password}" != "${second_password}" ]]; then
    echo "Passwords do not match." >&2
    exit 1
  fi

  REPLY=${first_password}
}

kubectl create namespace cnpg-database --dry-run=client --output yaml |
  kubectl apply --filename - >/dev/null
kubectl create namespace keycloak --dry-run=client --output yaml |
  kubectl apply --filename - >/dev/null

cnpg_secret_exists=false
keycloak_db_secret_exists=false
secret_exists cnpg-database keycloak-db-credentials && cnpg_secret_exists=true
secret_exists keycloak keycloak-externaldb && keycloak_db_secret_exists=true

if [[ "${cnpg_secret_exists}" == true ]]; then
  database_password=$(read_secret_key cnpg-database keycloak-db-credentials password)
elif [[ "${keycloak_db_secret_exists}" == true ]]; then
  database_password=$(read_secret_key keycloak keycloak-externaldb db-password)
else
  prompt_password "Keycloak database password"
  database_password=${REPLY}
fi

if [[ "${cnpg_secret_exists}" == true && "${keycloak_db_secret_exists}" == true ]]; then
  keycloak_database_password=$(read_secret_key keycloak keycloak-externaldb db-password)
  if [[ "${database_password}" != "${keycloak_database_password}" ]]; then
    echo "The existing CNPG and Keycloak database passwords do not match." >&2
    echo "Resolve the mismatch explicitly before running this script again." >&2
    exit 1
  fi
fi

printf '%s' keycloak >"${temporary_directory}/username"
printf '%s' "${database_password}" >"${temporary_directory}/password"
kubectl create secret generic keycloak-db-credentials \
  --namespace cnpg-database \
  --type kubernetes.io/basic-auth \
  --from-file="username=${temporary_directory}/username" \
  --from-file="password=${temporary_directory}/password" \
  --dry-run=client --output yaml |
  kubectl apply --filename - >/dev/null

printf '%s' "${database_password}" >"${temporary_directory}/db-password"
kubectl create secret generic keycloak-externaldb \
  --namespace keycloak \
  --from-file="db-password=${temporary_directory}/db-password" \
  --dry-run=client --output yaml |
  kubectl apply --filename - >/dev/null

if secret_exists keycloak keycloak; then
  echo "Preserved existing keycloak/keycloak administrator credentials."
else
  prompt_password "Keycloak administrator password"
  printf '%s' "${REPLY}" >"${temporary_directory}/admin-password"
  kubectl create secret generic keycloak \
    --namespace keycloak \
    --from-file="admin-password=${temporary_directory}/admin-password" \
    --dry-run=client --output yaml |
    kubectl apply --filename - >/dev/null
fi

unset database_password keycloak_database_password REPLY

echo "Keycloak bootstrap Secrets are ready:"
kubectl get secret keycloak-db-credentials --namespace cnpg-database
kubectl get secret keycloak keycloak-externaldb --namespace keycloak
