Installation
================

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


Create control-plane node
-----------------------

One one of the nodes, run the following command to initialize the control-plane node:

.. code-block:: bash

    sudo kubeadm init


This will output a command that you can run on the worker nodes to join the cluster. 
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


Installing Pod Network Add-on
----------------------------

This is required **only on the control-plane node**.

We need a Pod Network Add-on to enable communication between the pods in the cluster.
We will be using Calico as the Pod Network Add-on for this cluster. 

Run the following command to check if the control-plane node is ready:

.. code-block:: bash

    kubectl get nodes

    NAME              STATUS     ROLES           AGE   VERSION
    ip-172-31-17-15   NotReady   control-plane   12m   v1.34.4


This is expected as we have not installed the Pod Network Add-on yet. Once we install the Pod Network 
Add-on, the control-plane node will be in Ready state.


To install Calico, run the  following command on the control-plane node:

.. code-block:: bash

    kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/calico.yaml

Wait a few minutes for the control-plane node to be in Ready state. You can check the status of the nodes by running the following command:

.. code-block:: bash

    kubectl get pods -n kube-system -o wide

    NAME                                       READY   STATUS    RESTARTS   AGE   IP              NODE              NOMINATED NODE   READINESS GATES
    calico-kube-controllers-6fd9cc49d6-26g4l   1/1     Running   0          64s   192.168.123.2   ip-172-31-17-15   <none>           <none>
    calico-node-t75zw                          1/1     Running   0          64s   172.31.17.15    ip-172-31-17-15   <none>           <none>
    coredns-66bc5c9577-f2gkh                   1/1     Running   0          40m   192.168.123.3   ip-172-31-17-15   <none>           <none>
    coredns-66bc5c9577-rs77q                   1/1     Running   0          40m   192.168.123.1   ip-172-31-17-15   <none>           <none>
    etcd-ip-172-31-17-15                       1/1     Running   0          40m   172.31.17.15    ip-172-31-17-15   <none>           <none>
    kube-apiserver-ip-172-31-17-15             1/1     Running   0          40m   172.31.17.15    ip-172-31-17-15   <none>           <none>
    kube-controller-manager-ip-172-31-17-15    1/1     Running   0          40m   172.31.17.15    ip-172-31-17-15   <none>           <none>
    kube-proxy-ffv5v                           1/1     Running   0          40m   172.31.17.15    ip-172-31-17-15   <none>           <none>
    kube-scheduler-ip-172-31-17-15             1/1     Running   0          40m   172.31.17.15    ip-172-31-17-15   <none>           <none>


Now check the status of the nodes again:

.. code-block:: bash

    kubectl get nodes

    NAME              STATUS   ROLES           AGE   VERSION
    ip-172-31-17-15   Ready    control-plane   41m   v1.34.4


Now on each worker node, run the command that you copied from the output of `kubeadm init` to join 
the cluster. It will look something like this:


.. code-block:: bash

    sudo sudo kubeadm join 172.31.17.15:6443 --token goiv5k.ik18feg4jlgs97g0 --discovery-token-ca-cert-hash sha256:7ea3a847df3622aaedfe4380473838198a001f4d15fabd05a100d99d27e4dcf5


After running the above command on all worker nodes, check the status of the nodes again from the control-plane node:

.. code-block:: bash

    kubectl get nodes

    NAME               STATUS     ROLES           AGE   VERSION
    ip-172-31-17-15    Ready      control-plane   42m   v1.34.4
    ip-172-31-29-155   Ready      <none>          31s   v1.34.4
    ip-172-31-31-226   Ready   <none>          6s    v1.34.4


With this, we have successfully set up a Kubernetes cluster with one control-plane node and two worker nodes. 


Helm
----

Helm is a package manager for Kubernetes that allows you to easily deploy and manage applications on your cluster.

To install Helm, run the following command on your control-plane node:

.. code-block:: bash

    wget https://get.helm.sh/helm-v3.19.0-linux-amd64.tar.gz

    tar -xvf helm-v3.19.0-linux-amd64.tar.gz 

    sudo cp linux-amd64/helm /usr/local/bin/helm


NFS
----

To set up an NFS server, run the following command on one of the cp nodes:

.. code-block:: bash

    sudo apt-get install -y nfs-kernel-server

On the worker nodes install the nfs-common package:

.. code-block:: bash

    sudo apt-get install -y nfs-common



