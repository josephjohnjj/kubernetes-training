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

Platform ingress resources are managed by the `platform-ingresses` Argo CD
Application from `argocd/ingresses`. The copies under `manifests/ingress` are
retained for manual reference and must remain identical to the canonical Argo
CD files. Do not apply both copies as separate deployment sources.

The Keycloak and RBAC files remaining elsewhere in this directory have no
equivalent Argo CD Application. Applying them manually can create resources
that Argo CD will not reconcile.

When a compatibility copy exists here, keep it synchronized with its canonical
source above. Make deployment changes in the canonical source first.
