#!/bin/sh
set -eu

# Render every environment-specific nip.io hostname from the ingress Elastic
# IP managed by Terraform. This replaces the former Ansible inventory/template
# workflow; Talos nodes have no SSH or Ansible management surface.

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
TALOS_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
PROVISIONING_DIR=$(CDPATH= cd -- "$TALOS_DIR/.." && pwd)
REPOSITORY_ROOT=$(CDPATH= cd -- "$PROVISIONING_DIR/.." && pwd)

MODE=${1:-apply}
case "$MODE" in
  apply|--check)
    ;;
  *)
    echo "Usage: $0 [apply|--check]" >&2
    exit 2
    ;;
esac

INGRESS_IP=$(terraform -chdir="$PROVISIONING_DIR" output -json login_node_public_ips |
  jq -er 'if length == 1 then .[0] else error("expected exactly one ingress Elastic IP") end')

case "$INGRESS_IP" in
  *[!0-9.]*|.*|*.)
    echo "Invalid ingress IP returned by Terraform: $INGRESS_IP" >&2
    exit 1
    ;;
esac

PUBLIC_DOMAIN="$INGRESS_IP.nip.io"

# These are the deployable sources which contain environment-specific public
# hostnames. Documentation is intentionally excluded: examples and historical
# explanations should not be mechanically rewritten during a deployment.
TARGETS="
argocd/ingresses
manifests/ingress
charts/gen3/values/gen3-values.yaml
charts/gen3-2025.08/values/gen3-values.yaml
"

find_targets() {
  for relative_target in $TARGETS; do
    target="$REPOSITORY_ROOT/$relative_target"
    if [ -d "$target" ]; then
      find "$target" -type f \( -name '*.yaml' -o -name '*.yml' \) -print
    elif [ -f "$target" ]; then
      printf '%s\n' "$target"
    else
      echo "Configured render target does not exist: $relative_target" >&2
      return 1
    fi
  done
}

FILES=$(find_targets)

if [ "$MODE" = "--check" ]; then
  stale=0
  for file in $FILES; do
    if grep -E '[0-9]{1,3}(\.[0-9]{1,3}){3}\.nip\.io' "$file" |
      grep -Fv "$PUBLIC_DOMAIN" >/dev/null 2>&1; then
      echo "Stale nip.io hostname: ${file#"$REPOSITORY_ROOT/"}" >&2
      stale=1
    fi
  done

  if [ "$stale" -ne 0 ]; then
    echo "Run $0 apply to render $PUBLIC_DOMAIN." >&2
    exit 1
  fi

  echo "All deployable nip.io hostnames use $PUBLIC_DOMAIN."
  exit 0
fi

for file in $FILES; do
  PUBLIC_DOMAIN="$PUBLIC_DOMAIN" perl -0pi -e \
    's/[0-9]{1,3}(?:\.[0-9]{1,3}){3}\.nip\.io/$ENV{PUBLIC_DOMAIN}/g' \
    "$file"
done

"$0" --check
echo "Rendered environment-specific manifests from ingress IP $INGRESS_IP."
