#!/bin/sh
set -e

OUTPUTS=$(terraform -chdir=.. output -json)

SSH_KEY="$HOME/.ssh/terraform-user"

# Helper function
write_group() {
  GROUP_NAME=$1
  HOST_PREFIX=$2
  PUB_KEY=$3
  PRIV_KEY=$4

  PUBS=$(echo "$OUTPUTS" | jq -r "$PUB_KEY")
  PRIVS=$(echo "$OUTPUTS" | jq -r "$PRIV_KEY")

  echo "" >> host.ini
  echo "[$GROUP_NAME]" >> host.ini

  pub_file=$(mktemp)
  priv_file=$(mktemp)

  echo "$PUBS" > "$pub_file"
  echo "$PRIVS" > "$priv_file"

  count=1

  paste "$pub_file" "$priv_file" | while IFS="$(printf '\t')" read -r pub priv; do
    [ -z "$pub" ] && continue

    echo "${HOST_PREFIX}${count} ansible_host=$pub private_ip=$priv ansible_user=ubuntu ansible_ssh_private_key_file=$SSH_KEY" >> host.ini

    count=$((count + 1))
  done

  rm -f "$pub_file" "$priv_file"
}

# Create inventory
: > host.ini

write_group \
  "control" \
  "control" \
  '.control_node_public_ip.value[]' \
  '.control_node_private_ip.value[]'

write_group \
  "login" \
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

cat <<EOF >> host.ini

[worker:children]
worker_cpu
worker_gpu

[no_login:children]
control
worker
storage

[control_primary]
control1

[control_secondary]
control2
control3

[haproxy]
login1 


[all:children]
control
login
worker
storage
EOF

echo "Generated host.ini:"
cat host.ini