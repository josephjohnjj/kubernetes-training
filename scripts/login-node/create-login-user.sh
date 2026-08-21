#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  sudo ./scripts/login-node/create-login-user.sh <username>

Example:
  sudo ./scripts/login-node/create-login-user.sh alice

Run this script directly on the login node. It:
  1. Creates a non-privileged Linux user.
  2. Generates a passphrase-protected Ed25519 key in /root/login-user-keys/.
  3. Installs only the public key in the user's authorized_keys file.

Securely transfer the private key to the user and then remove the server copy.
EOF
}

if [[ $# -ne 1 ]]; then
  usage >&2
  exit 2
fi

if [[ $EUID -ne 0 ]]; then
  echo "Run this script as root using sudo." >&2
  echo "Example: sudo $0 alice" >&2
  exit 1
fi

username=$1

if [[ ! $username =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]; then
  echo "Invalid username: $username" >&2
  echo "Use a lowercase Linux username of at most 32 characters." >&2
  exit 2
fi

for command_name in getent ssh-keygen useradd; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Required command not found: $command_name" >&2
    exit 1
  fi
done

key_dir="/root/login-user-keys/$username"
private_key="$key_dir/id_ed25519"
public_key="$private_key.pub"

if [[ -e $private_key || -e $public_key ]]; then
  echo "Refusing to overwrite an existing key for $username:" >&2
  echo "  $key_dir" >&2
  exit 1
fi

if ! id "$username" >/dev/null 2>&1; then
  useradd --create-home --shell /bin/bash "$username"
  echo "Created Linux account: $username"
else
  echo "Linux account already exists: $username"
fi

user_home=$(getent passwd "$username" | cut -d: -f6)
user_group=$(id -gn "$username")

if [[ -z $user_home || $user_home == / ]]; then
  echo "Could not determine a safe home directory for $username" >&2
  exit 1
fi

install -d -m 0700 "$key_dir"

echo "Generating an Ed25519 key for $username."
echo "Enter a passphrase when prompted."
ssh-keygen \
  -t ed25519 \
  -a 100 \
  -C "$username@login-node" \
  -f "$private_key"

chmod 0600 "$private_key"
chmod 0644 "$public_key"

install -d -o "$username" -g "$user_group" -m 0700 "$user_home/.ssh"
install -d -o "$username" -g "$user_group" -m 0700 "$user_home/.kube"
touch "$user_home/.ssh/authorized_keys"
chown "$username:$user_group" "$user_home/.ssh/authorized_keys"
chmod 0600 "$user_home/.ssh/authorized_keys"

if ! grep -qxF "$(< "$public_key")" "$user_home/.ssh/authorized_keys"; then
  cat "$public_key" >> "$user_home/.ssh/authorized_keys"
fi

chown "$username:$user_group" "$user_home/.ssh/authorized_keys"

echo
echo "User created successfully."
echo "Private key: $private_key"
echo "Public key:  $public_key"
echo
echo "Next steps:"
echo "  1. Securely transfer $private_key to $username."
echo "  2. Test SSH access using the transferred key."
echo "  3. Remove the server-side private key after successful delivery:"
echo "       sudo rm '$private_key'"
echo
echo "The account was not granted sudo access or a Kubernetes kubeconfig."
