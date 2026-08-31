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
| Provisioning | AWS, Terraform, Talos Linux | [Talos provisioning](docs/source/talos.rst), [AWS cluster](docs/source/aws/aws_cluster.rst) |
| Cluster foundation | Talos, Kubernetes, Flannel, Helm | [Talos provisioning](docs/source/talos.rst), [Helm](docs/source/infrastructure/helm.rst) |
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
| Select the correct Talos cluster and AWS environment | `provisioning/talos/`, AWS/Terraform configuration | [Talos on AWS](docs/source/talos.rst), [prerequisites](docs/source/gen3/prerequisites.rst) |
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
Terraform resource historically named `login_node` is the `ingress1` ingress
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

./scripts/02-generate-config.sh

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

The workspace is `jxj900/ceph-cluster`. First synchronize the locally
configured AWS credentials as sensitive HCP **environment variables**, not
Terraform variables:

```bash
./scripts/01-sync-hcp-aws-credentials.sh
```

This manages `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and an optional
session token. Then sync the endpoint, current administrator `/32`, and
generated configuration as workspace Terraform variables:

```bash
export CONTROLPLANE_API_EIP_ALLOCATION_ID
./scripts/03-sync-hcp-variables.sh
```

The script sets:

```text
controlplane_api_eip_allocation_id
controlplane_machine_config  (sensitive)
worker_machine_config        (sensitive)
ingress_machine_config       (sensitive)
talos_api_allowed_cidrs
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

Wait until all control-plane instances have booted. Use the public Elastic IP
as the reachable Talos endpoint and the private address of `control1` as the
bootstrap node:

```bash
cd talos

CONTROL1_PRIVATE_IP="$(
  aws ec2 describe-instances \
    --region "$AWS_REGION" \
    --filters \
      'Name=tag:Name,Values=control1' \
      'Name=instance-state-name,Values=running' \
    --query 'Reservations[].Instances[].PrivateIpAddress' \
    --output text
)"

export CONTROL_PLANE_ENDPOINTS="$CONTROLPLANE_EIP"
export CONTROL_PLANE_NODES="$CONTROL1_PRIVATE_IP"
./scripts/04-bootstrap.sh
```

`04-bootstrap.sh` performs the one-time etcd bootstrap and writes
`generated/kubeconfig`. Never run `talosctl bootstrap` a second time for the
same cluster.

Verify the cluster:

```bash
export TALOSCONFIG="$PWD/generated/talosconfig"
export KUBECONFIG="$PWD/generated/kubeconfig"

talosctl health \
  --talosconfig "$TALOSCONFIG" \
  --endpoints "$CONTROLPLANE_EIP" \
  --nodes "$CONTROL1_PRIVATE_IP"
kubectl get nodes -o wide
kubectl get pods -A
```

### 8. Apply ingress-node metadata

Apply the node role, scheduler label, and dedicated taint required by the
ingress-nginx DaemonSet:

```bash
cd ../..
kubectl apply -f argocd/infrastructure/nodes/01-ingress-node.yaml
kubectl get node ingress1 --show-labels
```

### 9. Ingress addressing

Terraform assigns a separate Elastic IP to `ingress1`, the Talos ingress worker
(the Terraform output retains its historical `login_node` name):

```bash
terraform -chdir=provisioning output login_node_public_ips
```

Until a controlled domain is available, render platform hostnames from the
ingress address using nip.io, for example
`keycloak.<ingress-ip>.nip.io`. Public TCP 80 and 443 terminate directly at
ingress-nginx on `ingress1`.

## Render environment-specific manifests

After Terraform finishes, render every deployable ``nip.io`` hostname from
the ingress Elastic IP. The Talos workflow reads Terraform output directly and
does not generate an SSH or Ansible inventory:

```bash
cd provisioning/talos
./scripts/05-render-manifests.sh
./scripts/05-render-manifests.sh --check
```

The rendering script updates the platform ingress manifests and GEN3 values
from `terraform output login_node_public_ips` and builds the public domain as
`<ingress-public-ip>.nip.io`. Review and commit the generated changes before
Argo CD reads the `talos` branch.

## Install and synchronize with Argo CD

This section continues the canonical workflow in
[docs/source/talos.rst](docs/source/talos.rst). Keep the generated kubeconfig
active and run these commands from the repository root.

### 1. Install Argo CD

```bash
export KUBECONFIG="$PWD/provisioning/talos/generated/kubeconfig"

helm repo add argo https://argoproj.github.io/argo-helm
helm repo update argo
helm upgrade --install argocd argo/argo-cd \
  --version 10.3.3 \
  --namespace argocd \
  --create-namespace \
  --values charts/argocd/values.yaml \
  --wait \
  --timeout 10m

kubectl -n argocd wait \
  --for=condition=Available deployment --all --timeout=5m
```

Helm owns Argo CD. Do not apply `argocd/bootstrap/02-argocd-rbac-cm.yaml`;
the same policy is already managed through `charts/argocd/values.yaml`.

### 2. Reconcile infrastructure

Apply the AppProject before the infrastructure root Application:

```bash
kubectl apply -f argocd/bootstrap/01-project-infrastructure.yaml
kubectl apply -f argocd/bootstrap/03-infrastructure.yaml
kubectl -n argocd get applications --watch
```

The root discovers every Application below `argocd/infrastructure`.
Most children synchronize automatically. The Rook/Ceph Applications require
reviewed manual synchronization because self-healing and pruning are disabled.
Start the operator and CSI layer first:

```bash
for app in rook-ceph rook-ceph-csi; do
  kubectl patch application "$app" -n argocd \
    --type merge \
    -p '{"operation":{"sync":{"revision":"talos"}}}'
done

kubectl -n rook-ceph wait \
  --for=condition=Available deployment/rook-ceph-operator --timeout=5m
```

Create and verify the Ceph cluster before applying its pools, StorageClasses,
object storage, and toolbox. `Synced` alone does not mean a component is ready:

```bash
kubectl patch application rook-ceph-cluster -n argocd \
  --type merge \
  -p '{"operation":{"sync":{"revision":"talos"}}}'

kubectl -n rook-ceph get cephcluster rook-ceph
kubectl -n rook-ceph get pods

for app in rook-ceph-storage rook-ceph-tools; do
  kubectl patch application "$app" -n argocd \
    --type merge \
    -p '{"operation":{"sync":{"revision":"talos"}}}'
done

kubectl -n rook-ceph exec deploy/rook-ceph-tools -- ceph status
kubectl get storageclass cnpg-sc gen3-elasticsearch-sc gen3-bucket
kubectl -n cnpg-database get cluster,pod,pvc
kubectl -n elasticsearch get elasticsearch,pod,pvc
kubectl -n ingress-nginx get daemonset,pod
kubectl -n prometheus get daemonset,pod
```

### 3. Bootstrap and sync Keycloak

Run the credential bootstrap after the infrastructure root has created the
namespaces and CNPG resources:

```bash
./provisioning/talos/scripts/06-bootstrap-keycloak-secrets.sh

kubectl get secret keycloak-db-credentials -n cnpg-database
kubectl get secret keycloak keycloak-externaldb -n keycloak
```

Then synchronize CNPG’s managed role and perform Keycloak’s reviewed initial
sync:

```bash
kubectl patch application cnpg-database -n argocd \
  --type merge \
  -p '{"operation":{"sync":{"revision":"talos"}}}'

kubectl patch application keycloak -n argocd \
  --type merge \
  -p '{"operation":{"sync":{"revision":"talos"}}}'

kubectl -n keycloak rollout status statefulset/keycloak --timeout=5m
```

### 4. Reconcile workloads

Only continue after storage, CNPG, Elasticsearch, ingress-nginx, Prometheus,
and Keycloak are ready:

```bash
kubectl apply -f argocd/bootstrap/04-applications.yaml
kubectl -n argocd get applications --watch
```

The workload root discovers `gen3-db` at wave `10`, GEN3 at wave `20`, and the
optional small-LLM workload at wave `30`. Verify both sync and health:

```bash
kubectl -n argocd get applications
kubectl -n gen3-db get cluster,pod,pvc,job
kubectl -n gen3 get deployments,jobs,pods
kubectl -n gen3 wait \
  --for=condition=Available deployment --all --timeout=10m
```

If an Application is `Synced` but not healthy, inspect its workloads, custom
resources, and namespace events before forcing another synchronization.

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
provisioning/ Terraform and Talos cluster provisioning
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
