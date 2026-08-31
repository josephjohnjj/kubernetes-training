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
| Provisioning | AWS, Terraform, Talos Linux | [Talos provisioning](provisioning/talos/README.rst), [AWS cluster](docs/source/aws/aws_cluster.rst) |
| Cluster foundation | Talos, Kubernetes, Flannel, Helm | [Talos provisioning](provisioning/talos/README.rst), [Helm](docs/source/infrastructure/helm.rst) |
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

## Create and bootstrap the Talos cluster

The current AWS design creates a new Talos 1.13 cluster in one availability
zone. There is no SSH access, login host, HAProxy, or AWS load balancer. The
Terraform resource historically named `login_node` is the `login1` ingress
worker. ingress-nginx runs there as a host-network DaemonSet on ports 80 and
443.

The Kubernetes API uses a preallocated Elastic IP attached to `control1`.
Because this address is the external API endpoint, loss of `control1` also
removes external API access even if the other control-plane members remain
healthy.

### 1. Install matching clients

Install `talosctl` matching the selected Talos release, along with Terraform,
the AWS CLI, `kubectl`, and `jq`:

```bash
brew install siderolabs/tap/talosctl kubectl jq
```

The current machine configurations were generated with `talosctl` 1.13.7.

### 2. Resolve the Talos AWS AMI

Retrieve the official `amd64` AMI for the deployment region:

```bash
export AWS_REGION="us-east-1"
export TALOS_VERSION="v1.13.7"

AMI="$(
  curl -fsSL \
    "https://github.com/siderolabs/talos/releases/download/${TALOS_VERSION}/cloud-images.json" |
  jq -er --arg region "$AWS_REGION" \
    '.[] | select(.region == $region and .arch == "amd64") | .id'
)"

printf 'Talos AMI: %s\n' "$AMI"
```

Set the following HCP workspace Terraform variables to that AMI, except when a
role uses a custom Image Factory image:

```text
controller_ami
login_ami
worker_cpu_ami
worker_gpu_ami
storage_ami
```

GPU workers require a GPU EC2 instance type and eventually a Talos Image
Factory AMI containing the required GPU extensions. A `t3` or `t3a` instance is
not a GPU instance.

### 3. Preallocate the Kubernetes API address

Allocate the API Elastic IP before generating Talos configuration:

```bash
EIP_JSON="$(
  aws ec2 allocate-address \
    --region "$AWS_REGION" \
    --domain vpc \
    --output json
)"

export CONTROLPLANE_EIP="$(printf '%s' "$EIP_JSON" | jq -r '.PublicIp')"
export CONTROLPLANE_API_EIP_ALLOCATION_ID="$(
  printf '%s' "$EIP_JSON" | jq -r '.AllocationId'
)"

printf 'Public IP:     %s\n' "$CONTROLPLANE_EIP"
printf 'Allocation ID: %s\n' "$CONTROLPLANE_API_EIP_ALLOCATION_ID"
```

Do not release this address. Terraform attaches its allocation ID to
`control1`.

### 4. Generate and validate machine configuration

```bash
cd provisioning/talos

export CLUSTER_NAME="gen3"
export KUBERNETES_ENDPOINT="https://${CONTROLPLANE_EIP}:6443"

./scripts/generate-config.sh

wc -c \
  generated/controlplane.yaml \
  generated/worker.yaml \
  generated/ingress.yaml

talosctl validate --config generated/controlplane.yaml --mode cloud
talosctl validate --config generated/worker.yaml --mode cloud
talosctl validate --config generated/ingress.yaml --mode cloud
```

Each machine configuration must fit the EC2 16 KiB user-data limit. Generated
credentials are ignored by Git and must not be committed unencrypted.

### 5. Configure HCP Terraform

The workspace is `jxj900/ceph-cluster`. AWS credentials must be sensitive HCP
**environment variables**, not Terraform variables:

```text
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
```

Sync the endpoint, current administrator `/32`, and generated configuration as
workspace Terraform variables:

```bash
export CONTROLPLANE_API_EIP_ALLOCATION_ID
./scripts/sync-hcp-variables.sh
```

The script sets:

```text
controlplane_api_eip_allocation_id
controlplane_machine_config  (sensitive)
worker_machine_config        (sensitive)
ingress_machine_config       (sensitive)
talos_api_allowed_cidrs
```

If the existing AWS variables are in the wrong category, migrate the locally
configured AWS credentials to sensitive HCP environment variables:

```bash
./scripts/sync-hcp-aws-credentials.sh
```

Machine configuration is represented in remote Terraform state. Access to the
workspace and state must therefore be treated as privileged.

### 6. Plan and apply

```bash
cd ..
terraform state list
terraform plan
terraform apply
terraform output
```

For a new cluster, state is initially empty and the reviewed plan should contain
only additions. The first reviewed plan for this design reported `24 to add, 0
to change, 0 to destroy`.

### 7. Bootstrap Talos exactly once

Wait until all control-plane instances have booted. Configure the bootstrap
script with reachable control-plane addresses; the preallocated API Elastic IP
is sufficient for the initial bootstrap:

```bash
cd talos

export CONTROL_PLANE_NODES="$CONTROLPLANE_EIP"
./scripts/bootstrap.sh
```

`bootstrap.sh` performs the one-time etcd bootstrap and writes
`generated/kubeconfig`. Never run `talosctl bootstrap` a second time for the
same cluster.

Verify the cluster:

```bash
export TALOSCONFIG="$PWD/generated/talosconfig"
export KUBECONFIG="$PWD/generated/kubeconfig"

talosctl health --nodes "$CONTROLPLANE_EIP"
kubectl get nodes -o wide
kubectl get pods -A
```

### 8. Ingress addressing

Terraform assigns a separate Elastic IP to `login1`, the Talos ingress worker:

```bash
cd ../
terraform output login_node_public_ips
```

Until a controlled domain is available, render platform hostnames from the
ingress address using nip.io, for example
`keycloak.<ingress-ip>.nip.io`. Public TCP 80 and 443 terminate directly at
ingress-nginx on `login1`.

## Generate inventory and ingress manifests

After Terraform finishes, generate the Ansible inventory and render the
environment-specific platform ingress manifests:

```bash
cd provisioning/ansible
./01-generate-inventory.sh
ansible-playbook -i inventory.ini 02-render-manifests.yml
```

The rendering playbook reads the first host in the inventory's `ingress` group
and builds `publicDomain` as `<ingress-public-ip>.nip.io`. It writes the rendered
files to `argocd/ingresses/`. Review and commit those generated manifests before
Argo CD synchronizes them.

## Deployment order

The Argo CD Applications use dependency-based sync waves, but readiness must
still be verified between stateful layers:

1. Provision the nodes and Kubernetes cluster.
2. Install Argo CD and apply the infrastructure AppProject.
3. Reconcile namespaces, operators, ingress-nginx, CSI, and Prometheus.
4. Verify the Ceph cluster before applying pools and StorageClasses.
5. Reconcile PostgreSQL, search, observability, security, and scheduling services.
6. Create the required Keycloak Secrets, inspect the ``keycloak`` Application
   diff, and perform its initial adoption sync.
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
