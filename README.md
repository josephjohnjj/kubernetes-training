# Kubernetes Training and GEN3 Platform

This repository contains infrastructure-as-code, Kubernetes manifests, vendored
Helm charts, and Argo CD Applications for building a Kubernetes platform and
deploying GEN3 2025.08.

Argo CD is the intended source of truth. Files under `manifests/` are retained
for reference and selected operational tasks; do not apply that directory as a
second deployment source.

## Documentation

The complete documentation is maintained as Sphinx/RST content under
[`docs/source`](docs/source/index.rst). Start with:

- [GEN3 getting started](docs/source/gen3/getting_started.rst) for the canonical deployment procedure.
- [GEN3 prerequisites](docs/source/gen3/prerequisites.rst) for cluster, storage, networking, and tooling requirements.
- [Argo CD architecture](docs/source/argocd/architecture.rst) for the app-of-apps model and sync-wave order.
- [Argo CD repository paths](docs/source/argocd/repository_paths.rst) for GitOps ownership boundaries.
- [Readiness checks](docs/source/gen3/readiness.rst) for deployment gates and smoke tests.

## Infrastructure components

| Area | Components | Detailed documentation |
|---|---|---|
| Provisioning | AWS, Terraform, Ansible, HAProxy | [AWS cluster](docs/source/aws/aws_cluster.rst), [manual cluster](docs/source/aws/manual_kubernetes_cluster.rst), [HAProxy](docs/source/infrastructure/haproxy.rst) |
| Cluster foundation | Kubernetes, containerd, networking, Helm | [Cluster](docs/source/infrastructure/cluster.rst), [installation](docs/source/infrastructure/installation.rst), [Helm](docs/source/infrastructure/helm.rst) |
| GitOps | Argo CD, app-of-apps, sync waves | [Architecture](docs/source/argocd/architecture.rst), [bootstrap](docs/source/gen3/argocd_bootstrap.rst), [repository paths](docs/source/argocd/repository_paths.rst) |
| Ingress and certificates | ingress-nginx, cert-manager, platform ingresses | [Ingress NGINX](docs/source/configuration/ingress_nginx.rst), [cert-manager](docs/source/infrastructure/cert_manager.rst) |
| Storage | Rook, Ceph, block/file/object storage | [Ceph](docs/source/infrastructure/ceph.rst), [Rook-Ceph GitOps](docs/source/argocd/rook_ceph_bootstrap.rst), [GEN3 storage](docs/source/gen3/storage.rst) |
| Databases | CloudNativePG and PostgreSQL | [CloudNativePG](docs/source/infrastructure/cnpg.rst), [GEN3 PostgreSQL](docs/source/gen3/postgres.rst) |
| Identity | Keycloak and Argo CD OIDC | [Keycloak](docs/source/gen3/keycloak.rst), [Argo CD OIDC](docs/source/argocd/keycloak_oidc.rst) |
| Scheduling and ML | Kueue, Kubeflow Trainer, Argo Workflows | [Kueue](docs/source/infrastructure/kueue.rst), [Argo Workflows](docs/source/configuration/argo_workflows.rst) |
| Test inference | CPU-only Ollama and `qwen2.5:0.5b` | [Small LLM inference](docs/source/llm/small_llm.rst) |
| Metrics | Metrics Server, Prometheus, Grafana | [Metrics Server](docs/source/infrastructure/metric_server.rst), [Prometheus](docs/source/configuration/prometheus.rst), [Grafana](docs/source/configuration/grafana.rst) |
| Logs and search | Fluent Bit, OpenSearch, Elasticsearch | [Fluent Bit](docs/source/configuration/fluent_bit.rst), [OpenSearch](docs/source/configuration/opensearch.rst) |
| Tracing | Jaeger | [Jaeger](docs/source/configuration/jaeger.rst) |
| Security | RBAC, Kyverno, Trivy, Falco | [Kyverno](docs/source/configuration/kyverno.rst), [Trivy](docs/source/configuration/trivy.rst), [Falco](docs/source/infrastructure/falco.rst) |
| Workload | GEN3 2025.08 and supporting data services | [GEN3 overview](docs/source/gen3.rst), [components](docs/source/gen3/components.rst), [versions](docs/source/gen3/versions.rst) |

## Essential changes before deployment

This repository contains proof-of-concept and environment-specific values.
Review and replace the following before the first Argo CD synchronization:

| Required change | Primary locations | Instructions |
|---|---|---|
| Select the correct cluster and inventory | `provisioning/ansible/inventory.ini`, AWS/Terraform configuration | [AWS cluster deployment](docs/source/aws/aws_cluster.rst), [prerequisites](docs/source/gen3/prerequisites.rst) |
| Replace public IP addresses and `nip.io` hostnames | `argocd/ingresses/`, GEN3 and Keycloak values | [Ingress configuration](docs/source/configuration/ingress_nginx.rst), [GEN3 getting started](docs/source/gen3/getting_started.rst) |
| Confirm Ceph node names and raw devices | `storage/rook-ceph/cluster/01-rook-ceph-cluster.yaml` | [Ceph configuration](docs/source/infrastructure/ceph.rst), [storage requirements](docs/source/gen3/storage.rst) |
| Replace example passwords, access keys, and client secrets | `postgres/secrets/`, GEN3 values, Keycloak and Argo CD configuration | [Secrets inventory](docs/source/gen3/secrets.rst), [Keycloak](docs/source/gen3/keycloak.rst), [Argo CD OIDC](docs/source/argocd/keycloak_oidc.rst) |
| Review image and chart versions | `charts/`, Argo CD Application revisions | [Version inventory](docs/source/gen3/versions.rst) |
| Review storage capacity and StorageClasses | `storage/rook-ceph/storage/`, `postgres/`, chart values | [GEN3 storage](docs/source/gen3/storage.rst), [PostgreSQL](docs/source/gen3/postgres.rst) |
| Configure GEN3 hostname, dictionary, indices, resources, and UserSync source | `charts/gen3-2025.08/values/` and `values.d/` | [GEN3 getting started](docs/source/gen3/getting_started.rst), [data model](docs/source/gen3/data_model.rst) |
| Decide TLS, backup, retention, and recovery settings | Ingress, database, OpenSearch, and storage configuration | [Prerequisites](docs/source/gen3/prerequisites.rst), [readiness](docs/source/gen3/readiness.rst) |

Never use the example credentials with non-public data or expose them to the
internet. Do not allow Rook-Ceph to claim a device until its contents and target
node have been independently verified.

## Deployment order

The Argo CD Applications use dependency-based sync waves, but readiness must
still be verified between stateful layers:

1. Provision the nodes and Kubernetes cluster.
2. Install Argo CD and apply the infrastructure AppProject.
3. Reconcile namespaces, operators, ingress-nginx, CSI, and Prometheus.
4. Verify the Ceph cluster before applying pools and StorageClasses.
5. Reconcile PostgreSQL, search, observability, security, and scheduling services.
6. Configure Keycloak and required Secrets.
7. Reconcile `gen3-db` at wave `10`, then GEN3 at wave `20`.
8. Reconcile the optional `small-llm` test workload at wave `30`.
9. Run the documented readiness and ingress tests.

See [Argo CD bootstrap](docs/source/gen3/argocd_bootstrap.rst),
[sync-wave architecture](docs/source/argocd/architecture.rst), and
[readiness checks](docs/source/gen3/readiness.rst) for commands and health gates.

## Repository layout

```text
argocd/       Argo CD projects, root Applications, child Applications, ingresses
charts/       Vendored platform and GEN3 Helm charts
docs/source/  Sphinx/RST operator and deployment documentation
kueue/        Queue and resource-flavor configuration
llm/          Small test-model inference workloads
manifests/    Compatibility copies and manual-reference manifests
postgres/     GEN3 CloudNativePG resources and database initialization
provisioning/ Terraform and Ansible cluster provisioning
storage/      Rook-Ceph cluster and storage resources
tools/        Operational resources such as the Ceph toolbox
```

## Local validation

Render the exact GEN3 values stack before pushing a deployment change:

```bash
helm lint charts/gen3-2025.08 \
  -f charts/gen3-2025.08/values/gen3-values.yaml \
  -f charts/gen3-2025.08/values.d/00-etl-mapping.yaml \
  -f charts/gen3-2025.08/values.d/01-usersync.yaml \
  -f charts/gen3-2025.08/values.d/02-portal-gitops-css.yaml \
  -f charts/gen3-2025.08/values.d/03-portal-gitops-json.yaml
```

Build the documentation in an isolated environment:

```bash
python3 -m venv .venv-docs
source .venv-docs/bin/activate
pip install -r docs/requirements.txt
sphinx-build -W --keep-going -b html docs/source docs/build/html
```

Detailed validation and operational commands are documented in
[GEN3 getting started](docs/source/gen3/getting_started.rst) and
[readiness checks](docs/source/gen3/readiness.rst).
