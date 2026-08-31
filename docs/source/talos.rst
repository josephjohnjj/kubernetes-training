Talos on AWS
============

This guide records the procedure used to create the all-Talos AWS cluster.
Every control-plane, compute, storage, and ingress machine runs Talos Linux.
There is no SSH-based node administration and no AWS load balancer.  The
Terraform resource named ``login_node`` creates the Talos ingress worker.

The examples use Talos ``v1.13.7``, AWS region ``us-east-1``, and the
preallocated Kubernetes API Elastic IP ``100.61.11.217``.  Substitute the
values for a different deployment.

Use Talos AMIs for every node role
----------------------------------

Every control-plane, ingress, CPU worker, GPU worker, and storage instance
must boot a Talos AWS AMI.  A running EC2 instance is not sufficient evidence
that it joined Kubernetes: during this deployment, worker variables briefly
pointed at Ubuntu AMIs, so those instances ran ``systemd`` and the SSM agent
but never appeared as Talos nodes.

Resolve the official ``amd64`` AMI for the deployment region from the pinned
Talos release metadata::

   export AWS_REGION=us-east-1
   export TALOS_VERSION=v1.13.7

   TALOS_AMI="$(
     curl -fsSL \
       "https://github.com/siderolabs/talos/releases/download/${TALOS_VERSION}/cloud-images.json" |
     jq -er --arg region "$AWS_REGION" \
       '.[] | select(.region == $region and .arch == "amd64") | .id'
   )"

   printf 'Talos AMI: %s\n' "$TALOS_AMI"

Set the HCP Terraform variables ``controller_ami``, ``login_ami``,
``worker_cpu_ami``, ``worker_gpu_ami``, and ``storage_ami`` to an appropriate
Talos AMI.  The standard AMI is suitable for the current non-GPU instance
types.  A real NVIDIA worker requires a Talos Image Factory AMI containing the
required GPU extensions.

Addressing model
----------------

The Kubernetes API Elastic IP is attached to ``control1``.  It has two
different roles in the management workflow:

* ``--endpoints 100.61.11.217`` tells ``talosctl`` how the administrator
  workstation reaches a Talos API server.
* ``--nodes <private-control1-ip>`` identifies the machine on which the Talos
  operation is executed.

Do not use the public Elastic IP for both options.  After accepting the client
connection, the Talos endpoint routes the request to the selected node.  An
EC2 instance cannot reliably reach itself through its public Elastic IP, so
selecting that address as the node produces a misleading TCP 50000 timeout.
Use the private VPC address as the node target instead::

   talosctl version \
     --talosconfig ./generated/talosconfig \
     --endpoints 100.61.11.217 \
     --nodes 10.0.1.244

The private address may change when Terraform replaces an instance.  Resolve
it rather than copying the example value::

   CONTROL1_PRIVATE_IP="$(
     aws ec2 describe-instances \
       --region us-east-1 \
       --filters \
         'Name=tag:Name,Values=control1' \
         'Name=instance-state-name,Values=running' \
       --query 'Reservations[].Instances[].PrivateIpAddress' \
       --output text
   )"

Reserve the Kubernetes API address in AWS
-----------------------------------------

Reserve an EC2 Elastic IP before running Terraform or generating Talos
configuration.  Doing this first provides the stable address that is embedded
in the Kubernetes endpoint and its certificates.  The allocation is made
outside this Terraform state so destroying the cluster does not release the
address::

   export AWS_REGION=us-east-1

   EIP_JSON="$(
     aws ec2 allocate-address \
       --region "$AWS_REGION" \
       --domain vpc \
       --output json
   )"

   export CONTROLPLANE_EIP="$(
     printf '%s' "$EIP_JSON" | jq -r '.PublicIp'
   )"
   export CONTROLPLANE_API_EIP_ALLOCATION_ID="$(
     printf '%s' "$EIP_JSON" | jq -r '.AllocationId'
   )"

   printf 'Reserved public IP: %s\n' "$CONTROLPLANE_EIP"
   printf 'AWS allocation ID:  %s\n' \
     "$CONTROLPLANE_API_EIP_ALLOCATION_ID"

Tag the reservation so that it can be identified independently of shell
history or Terraform state::

   aws ec2 create-tags \
     --region "$AWS_REGION" \
     --resources "$CONTROLPLANE_API_EIP_ALLOCATION_ID" \
     --tags Key=Name,Value=talos-kubernetes-api

Verify the reservation before continuing::

   aws ec2 describe-addresses \
     --region "$AWS_REGION" \
     --allocation-ids "$CONTROLPLANE_API_EIP_ALLOCATION_ID" \
     --query 'Addresses[0].{PublicIp:PublicIp,AllocationId:AllocationId,InstanceId:InstanceId}' \
     --output table

Before Terraform runs, ``InstanceId`` is empty.  Terraform later creates
``aws_eip_association.controlplane_api`` and attaches the allocation ID to
``control1``.

If the shell variables are lost, recover the reservation by its tag::

   EIP_JSON="$(
     aws ec2 describe-addresses \
       --region "$AWS_REGION" \
       --filters 'Name=tag:Name,Values=talos-kubernetes-api' \
       --query 'Addresses[0]' \
       --output json
   )"

   export CONTROLPLANE_EIP="$(
     printf '%s' "$EIP_JSON" | jq -r '.PublicIp'
   )"
   export CONTROLPLANE_API_EIP_ALLOCATION_ID="$(
     printf '%s' "$EIP_JSON" | jq -r '.AllocationId'
   )"

For this deployment, the reserved values were::

   Public IP:     100.61.11.217
   Allocation ID: eipalloc-05923ace918dd4915

Do not run ``aws ec2 release-address`` for this allocation while the cluster
uses it.  Reuse the same reservation when rebuilding the cluster so the Talos
and Kubernetes endpoints remain stable.

Generate one shared configuration bundle
----------------------------------------

Use the reserved address when generating all machine configurations and
``talosconfig`` in one operation::

   cd provisioning/talos
   export CLUSTER_NAME=gen3
   export KUBERNETES_ENDPOINT="https://${CONTROLPLANE_EIP}:6443"

   ./scripts/generate-config.sh
   chmod 600 generated/talosconfig

   talosctl validate --config generated/controlplane.yaml --mode cloud
   talosctl validate --config generated/worker.yaml --mode cloud
   talosctl validate --config generated/ingress.yaml --mode cloud

The generated control-plane, worker, ingress, and client configurations share
one cluster trust domain.  Do not generate separate secrets for individual
nodes.  Do not commit the generated files; they contain cluster credentials.

Terraform gives each VM a stable hostname by replacing ``auto: stable`` in
the Talos 1.13 ``HostnameConfig`` document.  It deliberately preserves the
rest of the shared multi-document configuration and produces:

* ``control1``, ``control2``, and ``control3``.
* ``worker1`` through ``worker4``.
* ``storage1`` through ``storage3``.
* ``ingress1``.

Do not add the legacy ``machine.network.hostname`` field alongside
``HostnameConfig``.  Talos rejects that combination with ``static hostname is
already set`` and never starts its API.  Terraform validates that every HCP
machine configuration contains ``kind: HostnameConfig`` and ``auto: stable``
before performing the per-instance replacement.

The shared Talos patch explicitly sets
``cluster.allowSchedulingOnControlPlanes: false``.  Talos therefore maintains
``node-role.kubernetes.io/control-plane:NoSchedule`` on ``control1``,
``control2``, and ``control3``.  Ordinary workloads remain on worker and
storage nodes, while Kubernetes system DaemonSets with the standard control
plane toleration can still run where required.  Do not redeclare these
control-plane taints in separate Node manifests; Talos and Kubernetes own
their lifecycle.

Synchronize HCP Terraform before applying
------------------------------------------

The EC2 instances receive their Talos machine configurations through user
data.  Synchronize the newly generated files to HCP Terraform before creating
or replacing any instances::

   export CONTROLPLANE_API_EIP_ALLOCATION_ID
   ./scripts/sync-hcp-variables.sh

The script updates these workspace variables:

* ``controlplane_api_eip_allocation_id``
* ``controlplane_machine_config`` (sensitive)
* ``worker_machine_config`` (sensitive)
* ``ingress_machine_config`` (sensitive)
* ``talos_api_allowed_cidrs``

AWS credentials must be sensitive HCP environment variables, not Terraform
input variables.  Review the remote plan and then apply it::

   cd ..
   terraform plan
   terraform apply

When machine configuration changes, ``user_data_replace_on_change = true``
causes Terraform to replace the affected instances.  Confirm those
replacements appear in the plan before applying.

Verify the installed configuration
----------------------------------

Before bootstrap, confirm TCP 50000 is reachable::

   nc -vz -w 5 "$CONTROLPLANE_EIP" 50000

Compare the local control-plane configuration with the user data installed on
``control1`` without printing either secret::

   CONTROL1_ID="$(
     aws ec2 describe-instances \
       --region "$AWS_REGION" \
       --filters \
         'Name=tag:Name,Values=control1' \
         'Name=instance-state-name,Values=running' \
       --query 'Reservations[].Instances[].InstanceId' \
       --output text
   )"

   LOCAL_HASH="$(
     shasum -a 256 talos/generated/controlplane.yaml | awk '{print $1}'
   )"
   REMOTE_HASH="$(
     aws ec2 describe-instance-attribute \
       --region "$AWS_REGION" \
       --instance-id "$CONTROL1_ID" \
       --attribute userData \
       --query 'UserData.Value' \
       --output text |
     base64 --decode |
     shasum -a 256 |
     awk '{print $1}'
   )"

   printf 'Local:  %s\nRemote: %s\n' "$LOCAL_HASH" "$REMOTE_HASH"

AWS may omit the final newline, producing different whole-file hashes even
when the configuration is equivalent.  A one-byte size difference alone does
not indicate different secrets.  If authentication reports an unknown CA,
compare the parsed machine CA, token, cluster CA, and endpoint rather than
relying only on the whole-file hash.

Finally, verify authenticated access.  The endpoint is public, while the node
target is private::

   cd talos

   talosctl version \
     --talosconfig ./generated/talosconfig \
     --endpoints "$CONTROLPLANE_EIP" \
     --nodes "$CONTROL1_PRIVATE_IP"

Do not bootstrap until both the client and server versions are displayed.

Bootstrap exactly once
----------------------

Bootstrap etcd against one control-plane node only::

   talosctl bootstrap \
     --talosconfig ./generated/talosconfig \
     --endpoints "$CONTROLPLANE_EIP" \
     --nodes "$CONTROL1_PRIVATE_IP"

Successful bootstrap normally produces no output.  Never run bootstrap on the
other control-plane nodes, workers, storage nodes, or ingress node, and never
repeat bootstrap for the same cluster.  The remaining control-plane machines
join the bootstrapped etcd cluster automatically.

Check cluster health::

   talosctl health \
     --talosconfig ./generated/talosconfig \
     --endpoints "$CONTROLPLANE_EIP" \
     --nodes "$CONTROL1_PRIVATE_IP"

Immediately after bootstrap, ``etcd`` can be ``Preparing`` on the other
control-plane nodes.  Allow them several minutes to join.  If they remain
unhealthy, target their private addresses when checking services or logs::

   talosctl service etcd \
     --talosconfig ./generated/talosconfig \
     --endpoints "$CONTROLPLANE_EIP" \
     --nodes <private-control-plane-ips>

   talosctl logs etcd \
     --talosconfig ./generated/talosconfig \
     --endpoints "$CONTROLPLANE_EIP" \
     --nodes <unhealthy-private-ip>

Retrieve and use the Kubernetes configuration after the control plane becomes
healthy::

   talosctl kubeconfig ./generated/kubeconfig \
     --force \
     --talosconfig ./generated/talosconfig \
     --endpoints "$CONTROLPLANE_EIP" \
     --nodes "$CONTROL1_PRIVATE_IP"

   export KUBECONFIG="$PWD/generated/kubeconfig"
   kubectl get nodes -o wide
   kubectl get pods -A

Apply ingress node metadata from its manifest
---------------------------------------------

Kubernetes NodeRestriction prevents ``ingress1`` from assigning itself the
protected ``node-role.kubernetes.io/ingress`` label or changing its own taints.
Apply the repository's Kubernetes Node manifest instead of using separate
imperative ``kubectl label`` and ``kubectl taint`` commands::

   cd ../..
   kubectl apply -f argocd/infrastructure/nodes/01-ingress-node.yaml

The Node manifest declares:

* ``ingress-ready=true`` for the ingress-nginx node selector.
* ``node-role.kubernetes.io/ingress`` for the displayed Kubernetes role.
* ``dedicated=ingress:NoSchedule`` to reserve the node for tolerated ingress
  workloads.

The manifest marks the kubelet-owned Node as non-prunable.  Its sync-wave
annotation is inert during direct ``kubectl apply`` and becomes useful later
if the same manifest is reconciled by GitOps.

Troubleshooting the timeout
---------------------------

``nc`` or ``openssl`` succeeding does not prove that a complete Talos request
can reach the selected node.  Enable gRPC logging when the TCP and TLS checks
succeed but ``talosctl`` still reports a dial timeout::

   GRPC_GO_LOG_SEVERITY_LEVEL=info \
   GRPC_GO_LOG_VERBOSITY_LEVEL=99 \
   talosctl version \
     --talosconfig ./generated/talosconfig \
     --endpoints "$CONTROLPLANE_EIP" \
     --nodes "$CONTROL1_PRIVATE_IP"

If the channel reaches ``READY`` and the request later reports a timeout,
verify that ``--nodes`` contains a private VPC address rather than the public
Elastic IP.  An ``x509: certificate signed by unknown authority`` error instead
indicates that the client and installed machine configuration use different
Talos secret bundles, or that the Elastic IP still points at a replaced node
during association propagation.

Next step: install Argo CD with Helm
------------------------------------

The Talos cluster is complete when all eleven nodes are ``Ready``, the ingress
metadata manifest is applied, and ``talosctl health`` succeeds.  The next
layer is Argo CD.  Argo CD itself is installed and upgraded with the pinned
upstream Helm chart; this is the boundary between the Talos runbook and the
platform GitOps documentation.

Keep the Talos-generated kubeconfig active and install the chart from the
repository root::

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

Verify that Helm installed Argo CD into this cluster::

   helm status argocd --namespace argocd
   kubectl get pods --namespace argocd

Chart ``10.3.3`` installs Argo CD ``v3.5.1``.  Helm owns its CRDs, RBAC,
Services, and workloads.  Do not apply
``argocd/bootstrap/02-argocd-rbac-cm.yaml`` because the equivalent RBAC policy
is already managed by ``charts/argocd/values.yaml``.  Continue with
``gen3/argocd_bootstrap`` only after the Helm release is healthy.
