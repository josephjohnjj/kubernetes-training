#!/bin/sh
set -eu

ORGANIZATION=${HCP_ORGANIZATION:-jxj900}
WORKSPACE=${HCP_WORKSPACE:-ceph-cluster}
CREDENTIALS_FILE=${TF_CLI_CONFIG_FILE:-"$HOME/.terraform.d/credentials.tfrc.json"}
TOKEN=$(jq -er '.credentials["app.terraform.io"].token' "$CREDENTIALS_FILE")
API=https://app.terraform.io/api/v2
AUTH_HEADER="Authorization: Bearer $TOKEN"
CONTENT_HEADER="Content-Type: application/vnd.api+json"

AWS_ACCESS=$(aws configure get aws_access_key_id)
AWS_SECRET=$(aws configure get aws_secret_access_key)
AWS_SESSION=$(aws configure get aws_session_token || true)
test -n "$AWS_ACCESS"
test -n "$AWS_SECRET"

WORKSPACE_ID=$(curl -fsSL -H "$AUTH_HEADER" \
  "$API/organizations/$ORGANIZATION/workspaces/$WORKSPACE" | jq -er '.data.id')
VARSETS=$(curl -fsSL -H "$AUTH_HEADER" "$API/workspaces/$WORKSPACE_ID/varsets")

set_environment_variable() {
  key=$1
  value=$2
  found=false

  for set_id in $(printf '%s' "$VARSETS" | jq -r '.data[].id'); do
    variable=$(curl -fsSL -H "$AUTH_HEADER" "$API/varsets/$set_id/relationships/vars" |
      jq -r --arg key "$key" '.data[] | select(.attributes.key == $key) | [.id,.relationships.varset.data.id] | @tsv' |
      head -n 1)
    [ -n "$variable" ] || continue
    var_id=$(printf '%s' "$variable" | cut -f1)
    varset_id=$(printf '%s' "$variable" | cut -f2)
    payload=$(jq -n --arg key "$key" --arg value "$value" \
      '{data:{type:"vars",attributes:{key:$key,value:$value,category:"env",sensitive:true,hcl:false}}}')
    curl -fsSL -X PATCH -H "$AUTH_HEADER" -H "$CONTENT_HEADER" --data "$payload" \
      "$API/varsets/$varset_id/relationships/vars/$var_id" >/dev/null
    echo "Synced HCP environment variable: $key"
    found=true
    break
  done

  [ "$found" = true ] || {
    echo "Could not locate $key in an applied HCP variable set." >&2
    exit 1
  }
}

set_environment_variable AWS_ACCESS_KEY_ID "$AWS_ACCESS"
set_environment_variable AWS_SECRET_ACCESS_KEY "$AWS_SECRET"
if [ -n "$AWS_SESSION" ]; then
  set_environment_variable AWS_SESSION_TOKEN "$AWS_SESSION"
fi
