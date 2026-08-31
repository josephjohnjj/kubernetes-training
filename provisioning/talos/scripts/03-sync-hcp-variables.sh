#!/bin/sh
set -eu

ORGANIZATION=${HCP_ORGANIZATION:-jxj900}
WORKSPACE=${HCP_WORKSPACE:-ceph-cluster}
: "${CONTROLPLANE_API_EIP_ALLOCATION_ID:?Set CONTROLPLANE_API_EIP_ALLOCATION_ID}"
TALOS_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
CREDENTIALS_FILE=${TF_CLI_CONFIG_FILE:-"$HOME/.terraform.d/credentials.tfrc.json"}

TOKEN=$(jq -er '.credentials["app.terraform.io"].token' "$CREDENTIALS_FILE")
API=https://app.terraform.io/api/v2
AUTH_HEADER="Authorization: Bearer $TOKEN"
CONTENT_HEADER="Content-Type: application/vnd.api+json"

WORKSPACE_ID=$(curl -fsSL -H "$AUTH_HEADER" \
  "$API/organizations/$ORGANIZATION/workspaces/$WORKSPACE" |
  jq -er '.data.id')

VARIABLES=$(curl -fsSL -H "$AUTH_HEADER" "$API/workspaces/$WORKSPACE_ID/vars")

upsert_variable() {
  key=$1
  value=$2
  sensitive=$3
  hcl=$4
  existing_id=$(printf '%s' "$VARIABLES" |
    jq -r --arg key "$key" '.data[] | select(.attributes.key == $key and .attributes.category == "terraform") | .id' |
    head -n 1)

  payload=$(jq -n \
    --arg key "$key" \
    --arg value "$value" \
    --argjson sensitive "$sensitive" \
    --argjson hcl "$hcl" \
    '{data:{type:"vars",attributes:{key:$key,value:$value,category:"terraform",sensitive:$sensitive,hcl:$hcl}}}')

  if [ -n "$existing_id" ]; then
    curl -fsSL -X PATCH -H "$AUTH_HEADER" -H "$CONTENT_HEADER" \
      --data "$payload" "$API/vars/$existing_id" >/dev/null
  else
    curl -fsSL -X POST -H "$AUTH_HEADER" -H "$CONTENT_HEADER" \
      --data "$payload" "$API/workspaces/$WORKSPACE_ID/vars" >/dev/null
  fi

  echo "Synced Terraform variable: $key"
}

PUBLIC_IP=$(curl -fsSL https://checkip.amazonaws.com | tr -d '[:space:]')

upsert_variable controlplane_api_eip_allocation_id "$CONTROLPLANE_API_EIP_ALLOCATION_ID" false false
upsert_variable controlplane_machine_config "$(cat "$TALOS_DIR/generated/controlplane.yaml")" true false
upsert_variable worker_machine_config "$(cat "$TALOS_DIR/generated/worker.yaml")" true false
upsert_variable ingress_machine_config "$(cat "$TALOS_DIR/generated/ingress.yaml")" true false
upsert_variable talos_api_allowed_cidrs "[\"$PUBLIC_IP/32\"]" false true

printf '%s' "$VARIABLES" | jq -r '
  .data[] |
  select(.attributes.key == "AWS_ACCESS_KEY_ID" or .attributes.key == "AWS_SECRET_ACCESS_KEY") |
  "WARNING: \(.attributes.key) is configured as a \(.attributes.category) variable; it must be an environment variable."
'
