Talos cluster provisioning
==========================

All EC2 instances in this design run Talos. There is no SSH key, bastion host,
or node-level Ansible configuration. The Terraform resource still named
``login_node`` is temporarily retained to avoid an unnecessary state move; it
creates the ``ingress1`` Talos worker role.

All control-plane, ingress, compute, GPU, and storage instances are placed in
the single availability zone selected by ``target_az`` and in the subnet
selected by ``public_subnet_cidr``. This simplifies placement but means an
availability-zone outage affects the entire cluster.

Access model
------------

Use ``talosctl`` from an administrator workstation or CI runner. Set
``talos_api_allowed_cidrs`` to the VPN or administrator network allowed to
reach TCP 50000. Never expose TCP 50000 to the whole Internet.

The Kubernetes API endpoint should be a DNS name with one A record for each
control-plane address. Configure every control-plane address as a separate
``talosctl`` endpoint. Do not use an ingress worker as the Kubernetes API
endpoint.

When no controlled DNS name is available, preallocate an Elastic IP before
generating the machine configurations, use
``https://<elastic-ip>:6443`` as the endpoint, and provide its allocation ID as
``controlplane_api_eip_allocation_id``. Terraform attaches that address to
``control1``. This avoids an AWS load balancer but makes external API access
dependent on ``control1``.

Ingress
-------

The ``login1`` instance is now an ingress worker. Terraform assigns it an
Elastic IP, and its security group permits public TCP 80 and 443. The Talos
machine configuration for this node must include ``patches/ingress.yaml``.

The ingress-nginx chart runs a host-network DaemonSet selected by the
``ingress-ready=true`` node label. It binds directly to ports 80 and 443, so no
NodePort, HAProxy, or AWS load balancer is used. Point every public platform
hostname at the ``login_node_public_ips`` Terraform output. Add at least two
more ingress nodes before treating DNS-based ingress as highly available.

Configuration generation
------------------------

The scripts are numbered in execution order: configure HCP AWS credentials,
generate Talos configuration, synchronize HCP Terraform variables, bootstrap
the new cluster once, and finally render environment-specific manifests.
Run Terraform plan and apply after script 03 and before script 04.

Generate secrets and machine configurations with ``talosctl`` before running
Terraform. Use a client matching the Talos version installed by the selected
AMIs. Apply ``patches/cluster.yaml`` to all generated configurations and
``patches/ingress.yaml`` to the configuration for ``login1``.

For example::

   export CLUSTER_NAME=gen3
   export KUBERNETES_ENDPOINT=https://kube.example.internal:6443
   ./scripts/02-generate-config.sh

Supply the generated files as sensitive Terraform variables. Terraform passes
them to the instances as EC2 user data, which is how Talos obtains its initial
machine configuration on AWS::

   controlplane_machine_config = <contents of generated/controlplane.yaml>
   worker_machine_config       = <contents of generated/worker.yaml>
   ingress_machine_config      = <contents of generated/ingress.yaml>

Machine configuration contains cluster credentials and will be represented in
Terraform state. The remote state backend and access to it must therefore be
treated as secrets. Do not put these values in a committed ``tfvars`` file.

After Terraform starts the configured machines::

   export CONTROL_PLANE_ENDPOINTS="100.61.11.217"
   export CONTROL_PLANE_NODES="10.0.1.10"
   ./scripts/04-bootstrap.sh

``CONTROL_PLANE_ENDPOINTS`` is the Talos API address reachable from the
administrator workstation. ``CONTROL_PLANE_NODES`` starts with the private
address of the single control-plane machine that will bootstrap etcd.

The bootstrap operation must only be run once. Later instances obtain their
configuration from user data and join without bootstrapping etcd again.

Sensitive generated files such as ``secrets.yaml``, ``talosconfig``,
``controlplane.yaml``, ``worker.yaml``, and ``kubeconfig`` must not be committed
unencrypted.

Manifest rendering
------------------

Render environment-specific ``nip.io`` hostnames directly from the ingress
Elastic IP in Terraform output. This is the only useful function retained from
the former Ansible inventory/template workflow::

   ./scripts/05-render-manifests.sh
   ./scripts/05-render-manifests.sh --check

The script updates ``argocd/ingresses``, the legacy ``manifests/ingress``
copies, and both GEN3 values files. It fails unless Terraform reports exactly
one ingress Elastic IP and verifies that no stale ``nip.io`` IP remains in a
deployable target.
