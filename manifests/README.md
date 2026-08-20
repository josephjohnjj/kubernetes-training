# Legacy and manual manifests

The files in this directory are retained as manual examples and compatibility
copies. Argo CD does not currently scan or deploy the `manifests` directory.

Use the following Argo CD source paths as the canonical deployment files:

- Fluent Bit: `charts/fluent-bit`
- OpenSearch: `charts/opensearch`
- CloudNativePG cluster values: `charts/cloudnative-pg-cluster`
- PostgreSQL storage resources: `postgres`
- Kueue configuration: `kueue`
- Rook Ceph cluster and storage: `storage/rook-ceph`
- Rook Ceph toolbox resources: `tools/rook-ceph`

The ingress, Keycloak, and RBAC files in this directory have no equivalent
Argo CD Application in the current application tree. Applying them manually
can create resources that Argo CD will not reconcile.

When a compatibility copy exists here, keep it synchronized with its canonical
source above. Make deployment changes in the canonical source first.
