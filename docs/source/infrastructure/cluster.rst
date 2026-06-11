Kubernetes Cluster
===================

In this section, we will set up a Kubernetes cluster with three control-plane node and four worker nodes. 
We will be using kubeadm to set up the cluster.

Installing a container runtime
-----------------------------

On **all nodes** installing the container runtime containerd


.. code-block:: bash

    sudo apt update

    sudo apt install ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc
    


.. code-block:: bash

    sudo tee /etc/apt/sources.list.d/docker.sources <<EOF
    Types: deb
    URIs: https://download.docker.com/linux/debian
    Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
    Components: stable
    Signed-By: /etc/apt/keyrings/docker.asc
    EOF

.. code-block:: bash

    sudo apt update

    sudo apt install containerd.io 


Kubernets also requires Container Runtime Interface (CRI) to be enable. To check if CRI is enabled, run the following command:

.. code-block:: bash

    sudo crictl info

If this is note enabled, edit `/etc/containerd/config.toml` and replace

.. code-block:: bash

    disabled_plugins = ["cri"]

with 

.. code-block:: bash

    disabled_plugins = []

Then restart containerd

.. code-block:: bash

    sudo systemctl restart containerd

verify that CRI is enabled by running the following command again:

.. code-block:: bash

    sudo crictl info


Installing Kubernetes components
-----------------------------

On **all nodes** install kubeadm, kubelet and kubectl

.. code-block:: bash

    sudo apt-get update

    sudo apt-get install -y apt-transport-https ca-certificates curl gpg


.. code-block:: bash

    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.34/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg


.. code-block:: bash

    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.34/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list


.. code-block:: bash

    sudo apt-get update
    sudo apt-get install -y kubelet kubeadm kubectl
    sudo apt-mark hold kubelet kubeadm kubectl

    sudo systemctl enable --now kubelet

HA Proxy Load Balancer
-------------------------

HA Proxy is required for load balancing the control-plane nodes. We will be using HA Proxy as the load balancer for the control-plane nodes.
We will be installing HA proxy on the login node.

On the login node only, run the following command to install HA Proxy:

.. code-block:: bash

    sudo apt update
    sudo apt install -y haproxy


Backup the HA Proxy configuration file

.. code-block:: bash

    sudo cp /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.bak

Create a new HA Proxy configuration file with the following content:

.. code-block:: bash

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
        bind 0.0.0.0:6443
        default_backend k8s_api_backend

    backend k8s_api_backend
        balance roundrobin
        option tcp-check
        default-server inter 3s fall 3 rise 2

        server control1 10.0.1.207:6443 check
        server control2 10.0.1.99:6443 check
        server control3 10.0.1.123:6443 check

Validate the configuration

.. code-block:: bash

    sudo haproxy -c -f /etc/haproxy/haproxy.cfg


and then restart HA Proxy

.. code-block:: bash

    sudo systemctl enable haproxy
    sudo systemctl restart haproxy
    sudo systemctl status haproxy


Now lest change the firewall rules to allow traffic on port 6443 to the HA Proxy load balancer.

.. code-block:: bash

    sudo ufw allow 6443/tcp
    sudo ufw reload

.. code-block:: bash

    nc -vz 10.0.1.207 6443
    nc -vz 10.0.1.99 6443
    nc -vz 10.0.1.123 6443


This will show an error as we have not set up the control-plane nodes yet. We will set up the control-plane nodes in the next step and then 
check the connectivity again.

Create control-plane node
-----------------------

One one of the nodes, run the following command to initialize the control-plane node:

.. code-block:: bash

    sudo kubeadm init


This will output a command that you can run on the worker nodes and storage nodes to join the cluster. 
It will look something like this:

.. code-block:: bash

    kubeadm join <control-plane-node-ip>:6443 --token <token> \
        --discovery-token-ca-cert-hash sha256:<hash>

Make sure to copy this command to run it on the worker nodes later. 

To make kubectl work for your non-root user

.. code-block:: bash

    mkdir -p $HOME/.kube
    sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
    sudo chown $(id -u):$(id -g) $HOME/.kube/config


Now from the login node, check if you can access the Kubernetes API server through the HA Proxy load balancer by running the following command:

.. code-block:: bash

    nc -vz 10.0.1.207 6443
    Connection to 10.0.1.207 6443 port [tcp/*] succeeded!


Now use add the next two control-plane nodes to the cluster by running the kubeadm join command that you copied from the output of `kubeadm init` on 
the other two control-plane nodes. It will look something like this:

.. code-block:: bash

    kubeadm join 10.0.1.205:6443 --token 151mso.pcw7h97bnwp89ztu --discovery-token-ca-cert-hash \
    sha256:9eb2a9ef1d314f3f88863113d0b43d70843c4c6774a7a7fa095f54994c320e53  --control-plane --certificate-key \
    db0cfe59196dda444a923c72c4560754b7dfb1966347c21c25b79d71d776b319

Once the joining was successful, check the status of the nodes by running the following command, from the login node:

.. code-block:: bash

    nc -vz 10.0.1.207 6443
    nc -vz 10.0.1.99 6443
    nc -vz 10.0.1.123 6443


We can see that we can access the Kubernetes API server through the HA Proxy load balancer. Now we have successfully set up the control-plane nodes 
and the HA Proxy load balancer for our Kubernetes cluster.

From one of the control-plane nodes, check the status of the nodes by running the following command:

.. code-block:: bash

    kubectl get nodes

    NAME            STATUS     ROLES           AGE   VERSION

    control1      NotReady    control-plane   48m   v1.34.1
    control2      NotReady    control-plane   46m   v1.34.1
    control3      NotReady    control-plane   46m   v1.34.1



Now that the control plane nodes are set up, we can move on to setting up the worker nodes and then join them to the cluster.
Similar to the control-plane nodes, run the kubeadm join command that you copied from the output of `kubeadm init` on each worker node to 
join them to the cluster.

It will look something like this:

.. code-block:: bash

    kubeadm join 10.0.1.205:6443 --token 151mso.pcw7h97bnwp89ztu --discovery-token-ca-cert-hash \
    sha256:9eb2a9ef1d314f3f88863113d0b43d70843c4c6774a7a7fa095f54994c320e53 


Check the status of the nodes again from one of the control-plane nodes:

.. code-block:: bash

    kubectl get nodes

    NAME            STATUS     ROLES           AGE   VERSION

    control1      NotReady    control-plane   48m   v1.34.1
    control2      NotReady    control-plane   46m   v1.34.1
    control3      NotReady    control-plane   46m   v1.34.1
    cpu-worker1   NotReady    <none>          45m   v1.34.1
    cpu-worker2   NotReady    <none>          45m   v1.34.1
    gpu-worker1   NotReady    <none>          45m   v1.34.1
    gpu-worker2   NotReady    <none>          45m   v1.34.1
    storage1      NotReady    <none>          40m   v1.34.1
    storage2      NotReady    <none>          40m   v1.34.1
    storage3      NotReady    <none>          40m   v1.34.1


Installing Pod Network Add-on
----------------------------

A Kubernetes cluster requires a **Container Network Interface (CNI)** plugin to enable communication between Pods running on different nodes. In this 
cluster, **Calico** is used as the CNI plugin, providing Pod-to-Pod networking, routing between nodes, and support for network policies. 
Although the cluster may have multiple control-plane nodes, Calico only needs to be installed once by applying the Calico manifest with `kubectl` 
from any single control-plane node. 

This is because the installation creates Kubernetes resources such as DaemonSets and Deployments in the cluster state stored by the Kubernetes API. 
Once these resources are created, Kubernetes automatically deploys Calico Pods to all eligible nodes, including every control-plane and worker node. 
Since all control-plane nodes share the same cluster state, applying the manifest multiple times from different control-plane nodes is unnecessary and 
provides no additional benefit.



The nodes are not yet ready as we have not installed the Pod Network Add-on yet. Once we install 
the Pod Network Add-on, the control-plane node will be in Ready state.


To install Calico, run the  following command on the control-plane node:

.. code-block:: bash

    kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/calico.yaml

Wait a few minutes for the control-plane node to be in Ready state. You can check the status of the nodes by running the following command:

.. code-block:: bash

    kubectl get nodes

    NAME            STATUS   ROLES           AGE   VERSION
    control1      Ready    control-plane   48m   v1.34.1
    control2      Ready    control-plane   46m   v1.34.1
    control3      Ready    control-plane   46m   v1.34.1
    cpu-worker1   Ready    <none>          45m   v1.34.1
    cpu-worker2   Ready    <none>          45m   v1.34.1
    gpu-worker1   Ready    <none>          45m   v1.34.1
    gpu-worker2   Ready    <none>          45m   v1.34.1
    storage1      Ready    <none>          40m   v1.34.1
    storage2      Ready    <none>          40m   v1.34.1
    storage3      Ready    <none>          40m   v1.34.1


You can see that all the nodes are in Ready state now. You can also check the status of the pods in the kube-system namespace to see if the 
Calico pods are running:


.. code-block:: bash

    kubectl get pods -n kube-system -o wide

    NAME                                       READY   STATUS    RESTARTS   AGE    IP                NODE            NOMINATED NODE   READINESS GATES
    calico-kube-controllers-6fd9cc49d6-gv78m   1/1     Running   0          2m9s   192.168.235.131   ip-10-0-1-207   <none>           <none>
    calico-node-2mtwm                          1/1     Running   0          2m9s   10.0.1.99         ip-10-0-1-99    <none>           <none>
    calico-node-4nq4k                          1/1     Running   0          2m9s   10.0.1.254        ip-10-0-1-254   <none>           <none>
    calico-node-ggbs7                          1/1     Running   0          2m9s   10.0.1.228        ip-10-0-1-228   <none>           <none>
    calico-node-kr4xl                          1/1     Running   0          2m9s   10.0.1.207        ip-10-0-1-207   <none>           <none>
    calico-node-mcszt                          1/1     Running   0          2m9s   10.0.1.137        ip-10-0-1-137   <none>           <none>
    calico-node-pd8rz                          1/1     Running   0          2m9s   10.0.1.120        ip-10-0-1-120   <none>           <none>
    calico-node-z5rb6                          1/1     Running   0          2m9s   10.0.1.34         ip-10-0-1-34    <none>           <none>
    coredns-66bc5c9577-j2qkx                   1/1     Running   0          32m    192.168.235.129   ip-10-0-1-207   <none>           <none>
    coredns-66bc5c9577-rd72j                   1/1     Running   0          32m    192.168.235.130   ip-10-0-1-207   <none>           <none>
    etcd-ip-10-0-1-207                         1/1     Running   0          32m    10.0.1.207        ip-10-0-1-207   <none>           <none>
    etcd-ip-10-0-1-254                         1/1     Running   0          22m    10.0.1.254        ip-10-0-1-254   <none>           <none>
    etcd-ip-10-0-1-99                          1/1     Running   0          22m    10.0.1.99         ip-10-0-1-99    <none>           <none>
    kube-apiserver-ip-10-0-1-207               1/1     Running   0          32m    10.0.1.207        ip-10-0-1-207   <none>           <none>
    kube-apiserver-ip-10-0-1-254               1/1     Running   0          22m    10.0.1.254        ip-10-0-1-254   <none>           <none>
    kube-apiserver-ip-10-0-1-99                1/1     Running   0          22m    10.0.1.99         ip-10-0-1-99    <none>           <none>
    kube-controller-manager-ip-10-0-1-207      1/1     Running   0          32m    10.0.1.207        ip-10-0-1-207   <none>           <none>
    kube-controller-manager-ip-10-0-1-254      1/1     Running   0          22m    10.0.1.254        ip-10-0-1-254   <none>           <none>
    kube-controller-manager-ip-10-0-1-99       1/1     Running   0          22m    10.0.1.99         ip-10-0-1-99    <none>           <none>
    kube-proxy-4w5hb                           1/1     Running   0          17m    10.0.1.137        ip-10-0-1-137   <none>           <none>
    kube-proxy-9l9mf                           1/1     Running   0          22m    10.0.1.254        ip-10-0-1-254   <none>           <none>
    kube-proxy-bcr6w                           1/1     Running   0          17m    10.0.1.228        ip-10-0-1-228   <none>           <none>
    kube-proxy-d8smp                           1/1     Running   0          22m    10.0.1.99         ip-10-0-1-99    <none>           <none>
    kube-proxy-ldsws                           1/1     Running   0          17m    10.0.1.120        ip-10-0-1-120   <none>           <none>
    kube-proxy-mnrsk                           1/1     Running   0          17m    10.0.1.34         ip-10-0-1-34    <none>           <none>
    kube-proxy-vhpn4                           1/1     Running   0          32m    10.0.1.207        ip-10-0-1-207   <none>           <none>
    kube-scheduler-ip-10-0-1-207               1/1     Running   0          32m    10.0.1.207        ip-10-0-1-207   <none>           <none>
    kube-scheduler-ip-10-0-1-254               1/1     Running   0          22m    10.0.1.254        ip-10-0-1-254   <none>           <none>
    kube-scheduler-ip-10-0-1-99                1/1     Running   0          22m    10.0.1.99         ip-10-0-1-99    <none>           <none>


With this, we have successfully set up a Kubernetes cluster with three control-plane node and four worker nodes. 


Lets us label all nodes in the kubernetes cluster



.. code-block:: bash

    kubectl label node control1 control-plane=true
    kubectl label node control2 control-plane=true
    kubectl label node control3 control-plane=true


    kubectl label node worker1  worker-node=true
    kubectl label node worker2  worker-node=true
    kubectl label node worker3  worker-node=true
    kubectl label node worker4  worker-node=true

    kubectl label node storage1  ceph-storage=true
    kubectl label node storage2  ceph-storage=true
    kubectl label node storage3  ceph-storage=true

Verify the labels:

.. code-block:: bash

   kubectl get nodes --show-labels
   
