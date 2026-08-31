#!/bin/sh
set -eu

: "${CONTROL_PLANE_NODES:?Set CONTROL_PLANE_NODES to space-separated control-plane IPs}"
: "${CONTROL_PLANE_ENDPOINTS:=$CONTROL_PLANE_NODES}"

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
GENERATED_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/../generated" && pwd)

set -- $CONTROL_PLANE_NODES
BOOTSTRAP_NODE=$1
export TALOSCONFIG="$GENERATED_DIR/talosconfig"

talosctl config endpoint $CONTROL_PLANE_ENDPOINTS
talosctl bootstrap --nodes "$BOOTSTRAP_NODE"
talosctl kubeconfig "$GENERATED_DIR/kubeconfig" --nodes "$BOOTSTRAP_NODE"

echo "Bootstrap requested. Kubeconfig: $GENERATED_DIR/kubeconfig"
