#!/bin/sh
set -e

OUTPUTS=$(terraform -chdir=.. output -json)

CONTROL_PUBS=$(echo "$OUTPUTS" | jq -r '.control_node_public_ips.value[]')
LOGIN_PUB=$(echo "$OUTPUTS" | jq -r '.login_node_public_ips.value[0]')
WORKER_PUBS=$(echo "$OUTPUTS" | jq -r '.worker_node_public_ips.value[]')
STORAGE_PUBS=$(echo "$OUTPUTS" | jq -r '.storage_node_public_ips.value[]')

SSH_KEY="/home/joseph/.ssh/terraform-user"

# Start writing host.ini
cat <<EOF > host.ini
[control]
EOF

count=1

# Add control nodes
for ip in $CONTROL_PUBS; do
  [ -z "$ip" ] && continue
  echo "node$count ansible_host=$ip ansible_user=ubuntu ansible_ssh_private_key_file=$SSH_KEY" >> host.ini
  count=$((count + 1))
done

# Add login node
cat <<EOF >> host.ini

[login]
EOF

echo "node$count ansible_host=$LOGIN_PUB ansible_user=ubuntu ansible_ssh_private_key_file=$SSH_KEY" >> host.ini
count=$((count + 1))

# Add worker nodes
cat <<EOF >> host.ini

[worker]
EOF

for ip in $WORKER_PUBS; do
  [ -z "$ip" ] && continue
  echo "node$count ansible_host=$ip ansible_user=ubuntu ansible_ssh_private_key_file=$SSH_KEY" >> host.ini
  count=$((count + 1))
done

# Add storage nodes — continues numbering
cat <<EOF >> host.ini

[storage]
EOF

for ip in $STORAGE_PUBS; do
  [ -z "$ip" ] && continue
  echo "node$count ansible_host=$ip ansible_user=ubuntu ansible_ssh_private_key_file=$SSH_KEY" >> host.ini
  count=$((count + 1))
done

cat <<EOF >> host.ini

[all:children]
control
login
worker
storage
EOF

echo "Generated host.ini:"
cat host.ini
