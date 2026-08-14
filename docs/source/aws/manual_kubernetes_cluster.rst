Manual Kubernetes Cluster Installation
======================================

This page is a cleaned version of the original manual notes in
``infrastructure/cluster.rst``. It records how the self-managed Kubernetes
cluster was built with shell commands and kubeadm, without using Ansible.

The deployed topology contains three control-plane nodes, four application
workers, three storage workers, and a separate login node running HAProxy. The
login node is not joined to Kubernetes.

.. warning::

   This is a historical manual procedure. Prefer the reviewed Ansible
   playbooks for reproducibility and Argo CD for resources inside Kubernetes.
   Replace every placeholder, verify current software compatibility, and test
   the procedure in a disposable environment before rebuilding the cluster.

Node plan
---------

.. list-table::
   :header-rows: 1
   :widths: 30 20 50

   * - Nodes
     - Count
     - Role
   * - ``control1`` through ``control3``
     - 3
     - Highly available Kubernetes control plane and etcd
   * - ``cpu-worker1`` and ``cpu-worker2``
     - 2
     - General CPU workloads
   * - ``gpu-worker1`` and ``gpu-worker2``
     - 2
     - Worker group reserved for accelerator workloads
   * - ``storage1`` through ``storage3``
     - 3
     - Kubernetes workers with three data disks for Ceph
   * - ``login1``
     - 1
     - HAProxy endpoint, administration, and ingress forwarding

Before starting, assign stable private addresses or internal DNS names to every
host. Record these placeholders:

.. code-block:: text

   LOGIN_PRIVATE_IP=<login-node-private-ip>
   CONTROL1_PRIVATE_IP=<control1-private-ip>
   CONTROL2_PRIVATE_IP=<control2-private-ip>
   CONTROL3_PRIVATE_IP=<control3-private-ip>

AWS security rules must allow all required node-to-node Kubernetes and Calico
traffic. Administrator access to SSH, API port 6443, and web ports 80/443 should
be restricted to approved networks.

Prepare hostnames
-----------------

On every host, set the hostname corresponding to the node plan. For example, on
the first control-plane node::

   sudo hostnamectl set-hostname control1

Ensure every node can resolve the private names. Use private DNS or add all
nodes to ``/etc/hosts`` using their private addresses. Do not map a node name to
``127.0.1.1`` if Kubernetes should advertise its private address.

Install base packages
---------------------

Run on all Kubernetes nodes—control, application workers, and storage workers::

   sudo apt-get update
   sudo apt-get install -y \
     apt-transport-https ca-certificates curl gpg jq ncat

Install and configure containerd
--------------------------------

Run on every Kubernetes node. Add the Docker package repository matching the
host operating system::

   sudo install -m 0755 -d /etc/apt/keyrings
   curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
     | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
   sudo chmod a+r /etc/apt/keyrings/docker.gpg

   . /etc/os-release
   echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable" \
     | sudo tee /etc/apt/sources.list.d/docker.list

   sudo apt-get update
   sudo apt-get install -y containerd.io

Create a configuration and use the systemd cgroup driver::

   sudo mkdir -p /etc/containerd
   containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
   sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' \
     /etc/containerd/config.toml
   sudo systemctl enable --now containerd
   sudo systemctl restart containerd

Confirm that the CRI plugin is not listed under ``disabled_plugins`` and check
the service::

   sudo systemctl status containerd --no-pager
   sudo crictl info

If the installed containerd version generates a different configuration
schema, follow that version's documentation instead of applying the ``sed``
command blindly.

Configure Kubernetes prerequisites
----------------------------------

Run on every Kubernetes node::

   sudo tee /etc/modules-load.d/k8s.conf >/dev/null <<'EOF'
   overlay
   br_netfilter
   EOF

   sudo modprobe overlay
   sudo modprobe br_netfilter

   sudo tee /etc/sysctl.d/k8s.conf >/dev/null <<'EOF'
   net.bridge.bridge-nf-call-iptables  = 1
   net.bridge.bridge-nf-call-ip6tables = 1
   net.ipv4.ip_forward                 = 1
   EOF

   sudo sysctl --system
   sudo swapoff -a

Comment or remove swap entries in ``/etc/fstab`` so swap stays disabled after a
reboot. Verify::

   swapon --show
   sysctl net.ipv4.ip_forward

Install kubelet, kubeadm, and kubectl
-------------------------------------

The original cluster used Kubernetes ``1.34.1`` packages from the v1.34
repository. Run on every Kubernetes node::

   sudo mkdir -p /etc/apt/keyrings
   curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.34/deb/Release.key \
     | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

   echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.34/deb/ /' \
     | sudo tee /etc/apt/sources.list.d/kubernetes.list

   sudo apt-get update
   sudo apt-get install -y \
     kubelet=1.34.1-1.1 kubeadm=1.34.1-1.1 kubectl=1.34.1-1.1
   sudo apt-mark hold kubelet kubeadm kubectl
   sudo systemctl enable --now kubelet

The kubelet may restart until the node is initialized or joined. That is
expected. Confirm the desired package version still exists before recreating
the cluster.

Configure HAProxy manually
--------------------------

On ``login1``::

   sudo apt-get update
   sudo apt-get install -y haproxy
   sudo cp /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.bak

Replace ``/etc/haproxy/haproxy.cfg`` with a reviewed configuration using the
three private control-plane addresses::

   global
       log /dev/log local0
       log /dev/log local1 notice
       daemon

   defaults
       log global
       mode tcp
       timeout connect 10s
       timeout client 1m
       timeout server 1m
       option tcplog

   frontend k8s_api_frontend
       bind *:6443
       default_backend k8s_api_backend

   backend k8s_api_backend
       balance roundrobin
       option tcp-check
       default-server inter 3s fall 3 rise 2
       server control1 <CONTROL1_PRIVATE_IP>:6443 check
       server control2 <CONTROL2_PRIVATE_IP>:6443 check
       server control3 <CONTROL3_PRIVATE_IP>:6443 check

Validate and start HAProxy::

   sudo haproxy -c -f /etc/haproxy/haproxy.cfg
   sudo systemctl enable haproxy
   sudo systemctl restart haproxy
   sudo systemctl status haproxy --no-pager

Allow TCP 6443 through the host firewall if UFW is active::

   sudo ufw allow 6443/tcp
   sudo ufw reload

The backends remain unavailable until kubeadm starts the API servers.

Initialize ``control1``
-----------------------

On ``control1``, use the login node as the stable control-plane endpoint::

   sudo kubeadm init \
     --control-plane-endpoint '<LOGIN_PRIVATE_IP>:6443' \
     --upload-certs \
     --pod-network-cidr '192.168.0.0/16'

Save the control-plane join command, worker join command, certificate key, and
discovery hash in a secure temporary location. They are credentials and should
not be committed.

Configure kubectl for the administrative user::

   mkdir -p "$HOME/.kube"
   sudo cp /etc/kubernetes/admin.conf "$HOME/.kube/config"
   sudo chown "$(id -u):$(id -g)" "$HOME/.kube/config"
   chmod 600 "$HOME/.kube/config"

Verify the API through HAProxy::

   nc -vz <LOGIN_PRIVATE_IP> 6443
   kubectl get nodes

Join ``control2`` and ``control3``
----------------------------------

Run the control-plane join command produced by kubeadm on each secondary
control-plane node::

   sudo kubeadm join <LOGIN_PRIVATE_IP>:6443 \
     --token <BOOTSTRAP_TOKEN> \
     --discovery-token-ca-cert-hash sha256:<DISCOVERY_HASH> \
     --control-plane \
     --certificate-key <CERTIFICATE_KEY>

If the token or certificate key expires, generate replacements on ``control1``::

   sudo kubeadm token create --print-join-command
   sudo kubeadm init phase upload-certs --upload-certs

Confirm all three control-plane nodes appear::

   kubectl get nodes

Join workers and storage nodes
------------------------------

Run the worker form of the join command on ``cpu-worker1``, ``cpu-worker2``,
``gpu-worker1``, ``gpu-worker2``, and all three storage nodes::

   sudo kubeadm join <LOGIN_PRIVATE_IP>:6443 \
     --token <BOOTSTRAP_TOKEN> \
     --discovery-token-ca-cert-hash sha256:<DISCOVERY_HASH>

Nodes remain ``NotReady`` until the CNI is installed.

Install Calico
--------------

The original installation used Calico ``v3.27.0`` and Pod CIDR
``192.168.0.0/16``. Run once from ``control1``::

   curl -fsSLo /tmp/calico.yaml \
     https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/calico.yaml
   kubectl apply -f /tmp/calico.yaml

Downloading the manifest first permits inspection before application. Verify
that Calico supports the installed Kubernetes release and that its configured
IP pool matches the kubeadm Pod CIDR.

Wait for networking and DNS::

   kubectl -n kube-system rollout status daemonset/calico-node --timeout=5m
   kubectl -n kube-system rollout status deployment/calico-kube-controllers --timeout=5m
   kubectl -n kube-system rollout status deployment/coredns --timeout=5m
   kubectl get nodes

Label the nodes
---------------

Apply the labels used by the workload and storage configuration::

   kubectl label node control1 control-plane=true --overwrite
   kubectl label node control2 control-plane=true --overwrite
   kubectl label node control3 control-plane=true --overwrite

   kubectl label node cpu-worker1 worker-node=true --overwrite
   kubectl label node cpu-worker2 worker-node=true --overwrite
   kubectl label node gpu-worker1 worker-node=true --overwrite
   kubectl label node gpu-worker2 worker-node=true --overwrite

   kubectl label node storage1 ceph-storage=true --overwrite
   kubectl label node storage2 ceph-storage=true --overwrite
   kubectl label node storage3 ceph-storage=true --overwrite

Verify::

   kubectl get nodes --show-labels

Configure kubectl on the login node
-----------------------------------

Install the matching kubectl version on ``login1``. Securely copy
``/etc/kubernetes/admin.conf`` from ``control1`` to
``$HOME/.kube/config`` on the login node, then replace the server address with
the HAProxy endpoint::

   mkdir -p "$HOME/.kube"
   chmod 700 "$HOME/.kube"
   sed -i 's#server: https://.*:6443#server: https://<LOGIN_PRIVATE_IP>:6443#' \
     "$HOME/.kube/config"
   chmod 600 "$HOME/.kube/config"
   kubectl get nodes

``admin.conf`` grants cluster-admin access. Do not email it, commit it, or share
it as a general user kubeconfig.

Optional ingress forwarding
---------------------------

After ingress-nginx is installed, obtain its actual HTTP and HTTPS NodePorts::

   kubectl -n ingress-nginx get service ingress-nginx-controller

Add HAProxy frontends on ports 80 and 443 and backends pointing to reachable
Kubernetes nodes at those exact NodePorts. Do not copy historical NodePort
numbers without checking the live Service. Validate and restart HAProxy after
every change.

Storage-node disk preparation
-----------------------------

Before Rook-Ceph installation, inspect each storage node::

   lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,SERIAL

The expected OS device is ``/dev/nvme0n1`` and Ceph data devices are expected
to be ``/dev/nvme1n1`` through ``/dev/nvme3n1``. AWS device enumeration can
change, so verify each device rather than relying only on these names.

.. danger::

   The following commands irreversibly remove filesystem signatures and
   partition tables. Run them only on confirmed, empty Ceph data disks. Never
   run them on the operating-system disk.

For each confirmed Ceph disk::

   sudo wipefs -a /dev/nvme1n1
   sudo sgdisk --zap-all /dev/nvme1n1

Repeat only for the other verified data disks. Then hand storage installation
to the Rook-Ceph Argo CD Applications documented elsewhere.

Final cluster validation
------------------------

The manual Kubernetes installation is complete when all ten Kubernetes nodes
are ``Ready``, the three control-plane components are healthy, Calico runs on
every eligible node, CoreDNS is available, and HAProxy reaches the API::

   kubectl get nodes -o wide
   kubectl -n kube-system get pods -o wide
   kubectl get --raw='/readyz?verbose'
   kubectl get --raw='/livez?verbose'
   nc -vz <LOGIN_PRIVATE_IP> 6443

Also test pod scheduling and DNS::

   kubectl create deployment dns-test --image=nginx:stable
   kubectl rollout status deployment/dns-test --timeout=2m
   kubectl run dns-check --rm -it --restart=Never \
     --image=busybox:1.36 -- nslookup kubernetes.default.svc.cluster.local
   kubectl delete deployment dns-test

Next step
---------

Once the raw cluster is healthy, install Argo CD and let the repository's
Applications manage Rook-Ceph, databases, ingress, observability, and GEN3.
Avoid applying manual manifests for resources that Argo CD already owns.
