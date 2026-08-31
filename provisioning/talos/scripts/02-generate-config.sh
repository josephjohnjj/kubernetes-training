#!/bin/sh
set -eu

: "${CLUSTER_NAME:?Set CLUSTER_NAME}"
: "${KUBERNETES_ENDPOINT:?Set KUBERNETES_ENDPOINT to https://<dns-name>:6443}"

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
TALOS_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
GENERATED_DIR="$TALOS_DIR/generated"

if [ -e "$GENERATED_DIR" ]; then
  echo "Refusing to overwrite $GENERATED_DIR; move it aside or remove it deliberately." >&2
  exit 1
fi

mkdir -p "$GENERATED_DIR"
talosctl gen config "$CLUSTER_NAME" "$KUBERNETES_ENDPOINT" \
  --output-dir "$GENERATED_DIR" \
  --with-docs=false \
  --with-examples=false \
  --install-disk /dev/xvda \
  --config-patch "@$TALOS_DIR/patches/cluster.yaml"
talosctl machineconfig patch "$GENERATED_DIR/worker.yaml" \
  --patch "@$TALOS_DIR/patches/ingress.yaml" \
  --output "$GENERATED_DIR/ingress.yaml"

echo "Generated Talos configuration in $GENERATED_DIR. Keep it secret."
