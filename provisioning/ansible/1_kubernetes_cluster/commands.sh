# =====================================================
# ALL NODES
# Nodes:
# control1
# control2
# control3
# cpu-worker1
# cpu-worker2
# gpu-worker1
# gpu-worker2
# storage1
# storage2
# storage3
# =====================================================

sudo apt update

sudo apt install -y ca-certificates curl

sudo install -m 0755 -d /etc/apt/keyrings

sudo curl -fsSL https://download.docker.com/linux/debian/gpg \
-o /etc/apt/keyrings/docker.asc

sudo chmod a+r /etc/apt/keyrings/docker.asc


sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
Components: stable
Signed-By: /etc/apt/keyrings/docker.asc
EOF


sudo apt update

sudo apt install -y containerd.io


sudo crictl info


sudo systemctl restart containerd


sudo crictl info



# =====================================================
# ALL NODES
# Install Kubernetes components
# =====================================================

sudo apt-get update

sudo apt-get install -y apt-transport-https ca-certificates curl gpg


curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.34/deb/Release.key \
| sudo gpg --dearmor \
-o /etc/apt/keyrings/kubernetes-apt-keyring.gpg


echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
https://pkgs.k8s.io/core:/stable:/v1.34/deb/ /' \
| sudo tee /etc/apt/sources.list.d/kubernetes.list


sudo apt-get update

sudo apt-get install -y kubelet kubeadm kubectl


sudo apt-mark hold kubelet kubeadm kubectl


sudo systemctl enable --now kubelet



# =====================================================
# LOGIN NODE ONLY
# Install HAProxy
# =====================================================

# Node:
# login

sudo apt update

sudo apt install -y haproxy


sudo cp /etc/haproxy/haproxy.cfg \
/etc/haproxy/haproxy.cfg.bak


# Edit /etc/haproxy/haproxy.cfg
# Add:
#
# frontend k8s_api_frontend
#     bind 0.0.0.0:6443
#     default_backend k8s_api_backend
#
# backend k8s_api_backend
#     balance roundrobin
#     option tcp-check
#
#     server control1 10.0.1.207:6443 check
#     server control2 10.0.1.99:6443 check
#     server control3 10.0.1.123:6443 check


sudo haproxy -c -f /etc/haproxy/haproxy.cfg


sudo systemctl enable haproxy

sudo systemctl restart haproxy

sudo systemctl status haproxy


sudo ufw allow 6443/tcp

sudo ufw reload



# =====================================================
# LOGIN NODE ONLY
# Test API Load Balancer
# =====================================================

nc -vz 10.0.1.207 6443

nc -vz 10.0.1.99 6443

nc -vz 10.0.1.123 6443



# =====================================================
# CONTROL1 ONLY
# Initialise Kubernetes cluster
# =====================================================

# Node:
# control1

sudo kubeadm init \
--control-plane-endpoint "10.0.1.205:6443" \
--upload-certs



mkdir -p $HOME/.kube

sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config

sudo chown $(id -u):$(id -g) $HOME/.kube/config



# =====================================================
# CONTROL2 + CONTROL3
# Join additional control-plane nodes
# =====================================================

# Nodes:
# control2
# control3


kubeadm join 10.0.1.205:6443 \
--token <token> \
--discovery-token-ca-cert-hash sha256:<hash> \
--control-plane \
--certificate-key <certificate-key>



# =====================================================
# CONTROL1 ONLY
# Check nodes
# =====================================================

kubectl get nodes



# =====================================================
# WORKER NODES
# Join workers
#
# Nodes:
# cpu-worker1
# cpu-worker2
# gpu-worker1
# gpu-worker2
# storage1
# storage2
# storage3
# =====================================================


kubeadm join 10.0.1.205:6443 \
--token <token> \
--discovery-token-ca-cert-hash sha256:<hash>



# =====================================================
# CONTROL1 ONLY
# Install Calico CNI
# =====================================================

kubectl apply -f \
https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/calico.yaml



kubectl get nodes


kubectl get pods -n kube-system -o wide



# =====================================================
# CONTROL1 ONLY
# Add node labels
# =====================================================

kubectl label node control1 control-plane=true

kubectl label node control2 control-plane=true

kubectl label node control3 control-plane=true


kubectl label node cpu-worker1 worker-node=true

kubectl label node cpu-worker2 worker-node=true

kubectl label node gpu-worker1 worker-node=true

kubectl label node gpu-worker2 worker-node=true


kubectl label node storage1 ceph-storage=true

kubectl label node storage2 ceph-storage=true

kubectl label node storage3 ceph-storage=true



# Verify labels

kubectl get nodes --show-labels