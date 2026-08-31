#!/bin/sh
set -e

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
INVENTORY_FILE="$SCRIPT_DIR/inventory.ini"
OUTPUTS=$(terraform -chdir="$SCRIPT_DIR/.." output -json)

# Helper function
write_group() {
  GROUP_NAME=$1
  HOST_PREFIX=$2
  PUB_KEY=$3
  PRIV_KEY=$4

  PUBS=$(echo "$OUTPUTS" | jq -r "$PUB_KEY")
  PRIVS=$(echo "$OUTPUTS" | jq -r "$PRIV_KEY")

  echo "" >> "$INVENTORY_FILE"
  echo "[$GROUP_NAME]" >> "$INVENTORY_FILE"

  pub_file=$(mktemp)
  priv_file=$(mktemp)

  echo "$PUBS" > "$pub_file"
  echo "$PRIVS" > "$priv_file"

  count=1

  paste "$pub_file" "$priv_file" | while IFS="$(printf '\t')" read -r pub priv; do
    [ -z "$pub" ] && continue

    echo "${HOST_PREFIX}${count} ansible_host=$pub private_ip=$priv" >> "$INVENTORY_FILE"

    count=$((count + 1))
  done

  rm -f "$pub_file" "$priv_file"
}

# Create inventory
: > "$INVENTORY_FILE"

write_group \
  "control" \
  "control" \
  '.control_node_public_ip.value[]' \
  '.control_node_private_ip.value[]'

write_group \
  "ingress" \
  "login" \
  '.login_node_public_ips.value[]' \
  '.login_node_private_ips.value[]'

write_group \
  "worker_cpu" \
  "cpu-worker" \
  '.worker_node_cpu_public_ips.value[]' \
  '.worker_node_cpu_private_ips.value[]'

write_group \
  "worker_gpu" \
  "gpu-worker" \
  '.worker_node_gpu_public_ips.value[]' \
  '.worker_node_gpu_private_ips.value[]'

write_group \
  "storage" \
  "storage" \
  '.storage_node_public_ips.value[]' \
  '.storage_node_private_ips.value[]'

cat <<EOF >> "$INVENTORY_FILE"

[worker:children]
worker_cpu
worker_gpu
ingress

[no_login:children]
control
worker
storage

[control_primary]
control1

[control_secondary]
control2
control3

[all:children]
control
ingress
worker
storage
EOF

echo "Generated $INVENTORY_FILE:"
cat "$INVENTORY_FILE"
