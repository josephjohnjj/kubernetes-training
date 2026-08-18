AWS and Kubernetes Cluster Provisioning
=======================================

This page records how the AWS infrastructure and self-managed Kubernetes
cluster were provisioned for the GEN3 deployment. AWS resources are defined by
Terraform under ``provisioning``. Operating-system and Kubernetes configuration
is implemented by Ansible under ``provisioning/ansible`` and corresponds to the
manual process previously described in ``infrastructure/cluster.rst``.

This is a kubeadm cluster running on EC2, not Amazon EKS.

Architecture
------------

The default Terraform configuration creates eleven EC2 instances in one public
subnet:

.. list-table::
   :header-rows: 1
   :widths: 25 15 25 35

   * - Role
     - Count
     - Default instance type
     - Purpose
   * - Control plane
     - 3
     - ``t3.2xlarge``
     - API server, scheduler, controller manager, and etcd
   * - Login/HAProxy
     - 1
     - ``t3.small``
     - SSH access, Kubernetes API load balancing, and ingress forwarding
   * - CPU worker
     - 2
     - ``t3.2xlarge``
     - General application workloads
   * - GPU worker group
     - 2
     - ``t3.2xlarge``
     - Named as GPU workers, but the configured type has no GPU
   * - Storage
     - 3
     - ``t3.2xlarge``
     - Kubernetes workers dedicated to Rook-Ceph OSDs

The resulting Kubernetes layout is::

   Internet
      |
      v
   Login node / HAProxy
      +-- :6443 --> three kube-apiserver instances
      +-- :80   --> ingress-nginx HTTP NodePort
      +-- :443  --> ingress-nginx HTTPS NodePort

   Kubernetes cluster
      +-- 3 control-plane nodes
      +-- 2 CPU worker nodes
      +-- 2 worker nodes assigned to the GPU inventory group
      +-- 3 Ceph storage nodes

Terraform state and provider
----------------------------

``provisioning/main.tf`` requires Terraform 1.2 or newer and AWS provider 5.0
or newer. Remote state is held in Terraform Cloud organization ``jxj900``,
workspace ``ceph-cluster``. The AWS provider is configured for ``us-east-1``;
the default Availability Zone is ``us-east-1c``.

Authenticate to AWS and Terraform Cloud using approved local mechanisms. Do not
put access keys in Terraform files or shell history::

   cd provisioning
   terraform login
   terraform init
   terraform validate
   terraform plan

Review the complete plan before applying::

   terraform apply

.. warning::

   ``terraform apply`` changes AWS resources and may incur significant cost.
   ``terraform destroy`` removes instances and their delete-on-termination EBS
   volumes. Confirm the Terraform Cloud workspace and AWS account before either
   command.

AWS network resources
---------------------

Terraform creates:

* VPC ``main-vpc`` with CIDR ``10.0.0.0/16``.
* Public subnet ``10.0.1.0/24`` with automatic public addresses.
* An Internet Gateway and a default route to ``0.0.0.0/0``.
* VPC DNS support and DNS hostnames.

Every EC2 instance is placed in that public subnet and receives a public IP.
The address is not an Elastic IP and can change when an instance is replaced.
Environment-specific ``nip.io`` hostnames and Ansible inventory must be updated
after an address change.

Security groups
---------------

The configuration defines:

* ``ssh-sg``: SSH port 22 from every IPv4 and IPv6 address.
* ``internal-sg``: all protocols between members of the security group.
* ``monitoring-sg``: public ports 80 and 443, attached to control and login
  nodes.
* ``efs-sg``: NFS port 2049 from instances in ``internal-sg``.

.. warning::

   Public SSH from ``0.0.0.0/0`` and ``::/0`` is unsafe for a durable
   environment. Restrict it to approved administrator networks or a VPN/bastion.
   Review whether control-plane nodes need the public HTTP/HTTPS security group.

EC2 storage
-----------

All volumes use gp3 with 3,000 IOPS and are deleted when their instance is
terminated:

* Control nodes: ``200Gi`` root plus one ``150Gi`` data disk.
* Login node: ``100Gi`` root.
* CPU and GPU inventory workers: ``200Gi`` root plus one ``200Gi`` data disk.
* Storage nodes: ``100Gi`` root plus three ``200Gi`` data disks.

On Nitro-based EC2 instances, the three storage volumes appear as
``/dev/nvme1n1``, ``/dev/nvme2n1``, and ``/dev/nvme3n1``. Rook-Ceph consumes
these devices.

.. warning::

   The Terraform configuration currently sets EBS encryption to false. Enable
   encryption with an approved KMS key before recreating a production cluster.
   Never assume an NVMe device name: verify serial numbers and mappings with
   ``lsblk`` and ``nvme id-ctrl`` before wiping a disk.

SSH key and inventory
---------------------

Terraform registers ``provisioning/keys/terraform-user.pub`` as AWS key pair
``terraform-user``. The private key must already exist securely on the Ansible
control machine and must not be committed.

Terraform outputs public and private IP lists for each node role::

   terraform output
   terraform output -json

Generate the Ansible inventory from those outputs::

   cd provisioning/ansible
   ./generate-inventory.sh

The script creates groups for ``control``, ``login``, ``worker_cpu``,
``worker_gpu``, and ``storage``, plus these functional groups:

* ``control_primary``: ``control1``.
* ``control_secondary``: ``control2`` and ``control3``.
* ``worker``: both worker groups.
* ``no_login``: all Kubernetes nodes except the login node.
* ``haproxy``: ``login1``.

Review ``inventory.ini`` and test access::

   ansible -i inventory.ini all -m ping

Do not publish the generated inventory because it contains current public IPs
and a local private-key path.

Kubernetes software baseline
----------------------------

The Ansible playbooks configure:

* Ubuntu base packages and node hostnames.
* containerd with CRI enabled.
* Kubernetes ``1.34.1`` packages from the v1.34 repository.
* kubelet, kubeadm, and kubectl held against automatic package upgrades.
* Swap disabled.
* Kernel modules ``overlay`` and ``br_netfilter``.
* IPv4 forwarding and bridge netfilter sysctls.
* Calico ``v3.27.0`` with Pod CIDR ``192.168.0.0/16``.

Version compatibility must be revalidated before recreation. In particular,
confirm that the selected Calico release supports the selected Kubernetes
release.

Configure the operating system
------------------------------

From ``provisioning/ansible``, run the base preparation on all nodes, then the
container runtime and Kubernetes prerequisites on Kubernetes nodes::

   ansible-playbook -i inventory.ini kubernetes-cluster/01-prepare-hosts.yml
   ansible-playbook -i inventory.ini kubernetes-cluster/02-configure-containerd-repository.yml
   ansible-playbook -i inventory.ini kubernetes-cluster/03-configure-containerd.yml
   ansible-playbook -i inventory.ini kubernetes-cluster/04-install-kubernetes.yml
   ansible-playbook -i inventory.ini kubernetes-cluster/05-configure-kubernetes-prerequisites.yml

The base playbook may perform a distribution upgrade and reboot nodes. Confirm
SSH access again before continuing.

Configure HAProxy
-----------------

The login node provides the stable kubeadm control-plane endpoint and forwards
public web traffic to ingress-nginx::

   ansible-playbook -i inventory.ini haproxy/01-install-kubectl.yml
   ansible-playbook -i inventory.ini haproxy/02-configure-haproxy.yml

The playbook listens on:

* Port 6443 for the Kubernetes API.
* Port 80 for ingress-nginx NodePort 30253.
* Port 443 for ingress-nginx NodePort 31917.

Verify these NodePorts against the live ingress-nginx Service. If Kubernetes
assigns different ports, update the HAProxy playbook before restarting it.

The current template uses each control node's ``ansible_host`` as its backend,
which is the public address from the generated inventory. Private addresses are
preferable for traffic inside the VPC.

Initialize the primary control plane
------------------------------------

``06-initialize-primary-control-plane.yml`` calculates the control-plane endpoint from the login
node's private IP and initializes Kubernetes with kubeadm::

   ansible-playbook -i inventory.ini kubernetes-cluster/06-initialize-primary-control-plane.yml

Conceptually, it runs::

   kubeadm init \
     --control-plane-endpoint '<LOGIN_PRIVATE_IP>:6443' \
     --upload-certs \
     --pod-network-cidr '192.168.0.0/16'

The playbook creates kubeconfigs for root and the Ubuntu user and stores worker
and control-plane join scripts under ``/etc/kubernetes/bootstrap`` on
``control1``. These scripts contain time-limited tokens and certificate keys;
protect them as credentials.

Join the remaining nodes
------------------------

Join secondary control-plane nodes first::

   ansible-playbook -i inventory.ini kubernetes-cluster/07-join-secondary-control-planes.yml

Then join application workers and storage nodes::

   ansible-playbook -i inventory.ini kubernetes-cluster/09-join-worker-nodes.yml
   ansible-playbook -i inventory.ini kubernetes-cluster/10-join-storage-nodes.yml

The playbooks do not run ``kubeadm join`` again when
``/etc/kubernetes/kubelet.conf`` already exists.

Install Calico
--------------

Install the CNI once from the primary control plane::

   ansible-playbook -i inventory.ini kubernetes-cluster/08-install-calico.yml

Before Calico starts, nodes normally report ``NotReady``. After installation,
verify Calico, CoreDNS, kube-proxy, and all nodes::

   kubectl -n kube-system get pods -o wide
   kubectl get nodes

Configure labels and kubeconfig
-------------------------------

Apply the role labels used by scheduling and storage configuration::

   ansible-playbook -i inventory.ini kubernetes-cluster/11-label-nodes.yml

This applies:

* ``control-plane=true`` to control nodes.
* ``worker-node=true`` to CPU and GPU inventory workers.
* ``ceph-storage=true`` to storage nodes.

Copy kubeconfig to all control-plane nodes::

   ansible-playbook -i inventory.ini kubernetes-cluster/12-configure-control-plane-kubeconfig.yml

After the API is available, install a login-node kubeconfig that points through
HAProxy::

   ansible-playbook -i inventory.ini haproxy/03-configure-login-kubeconfig.yml

Ceph disk preparation
---------------------

The storage nodes have three data devices reserved for Ceph. Inspect them on
every node before running the destructive playbook::

   ansible -i inventory.ini storage -b -m shell -a 'lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS'

Only after validating the target devices, run::

   ansible-playbook -i inventory.ini kubernetes-cluster/16-wipe-storage-disks.yml --tags check
   ansible-playbook -i inventory.ini kubernetes-cluster/16-wipe-storage-disks.yml --tags wipe,verify

.. danger::

   The wipe tasks run ``wipefs -a`` and ``sgdisk --zap-all`` on
   ``/dev/nvme1n1``, ``/dev/nvme2n1``, and ``/dev/nvme3n1``. This destroys
   partition tables and filesystem signatures. The playbook protects only
   ``/dev/nvme0n1`` by name; stop if actual device mappings differ.

Final validation
----------------

Run the cluster verification playbook and inspect Kubernetes directly::

   ansible-playbook -i inventory.ini kubernetes-cluster/14-verify-cluster.yml
   kubectl get nodes -o wide
   kubectl get nodes --show-labels
   kubectl -n kube-system get pods
   kubectl get --raw='/readyz?verbose'

Expected results are three ready control-plane nodes, seven ready worker/storage
nodes, healthy CoreDNS and Calico, and successful API access through HAProxy.

Known issues and improvements
-----------------------------

Address these before treating the process as production-ready:

* Restrict public SSH and minimize public IP exposure.
* Enable EBS encryption.
* Use actual GPU instance types or rename the GPU inventory group.
* Use private HAProxy backend addresses.
* Assign an Elastic IP or managed DNS name to the login endpoint.
* Pin and checksum all downloaded manifests.
* Confirm Kubernetes and Calico compatibility.
* Run the complete non-destructive cluster workflow from
  ``provisioning/ansible`` with
  ``ansible-playbook -i inventory.ini 01-deploy.yaml``. Disk wiping,
  troubleshooting, Keycloak, and Argo CD are intentionally excluded.
* Test etcd backup and control-plane disaster recovery before workloads are
  installed.

Handoff to Argo CD
------------------

Terraform and Ansible establish AWS, Kubernetes, networking, labels, and raw
Ceph devices. After the cluster passes validation, install Argo CD and use the
Git-managed Applications for Rook-Ceph, databases, ingress, observability, and
GEN3. Avoid continuing with unrelated manual manifests when an Argo CD source
already owns the resource.
