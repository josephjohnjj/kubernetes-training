Important Caveats
========================

When upgrading a cluster, it's important to recognize that each component, developed by different teams, is versioned and tested for compatibility. 
Mismatches in versions can lead to instability or errors.

To ensure a successful upgrade, use commands like the one below:


.. code-block:: bash

    kubeadm upgrade plan

    Components that must be upgraded manually after you have upgraded the control plane with 'kubeadm upgrade apply':
    COMPONENT   NODE               CURRENT   TARGET
    kubelet     ip-172-31-17-15    v1.34.4   v1.34.7
    kubelet     ip-172-31-29-155   v1.34.4   v1.34.7
    kubelet     ip-172-31-31-226   v1.34.4   v1.34.7

    Upgrade to the latest version in the v1.34 series:

    COMPONENT                 NODE              CURRENT   TARGET
    kube-apiserver            ip-172-31-17-15   v1.34.4   v1.34.7
    kube-controller-manager   ip-172-31-17-15   v1.34.4   v1.34.7
    kube-scheduler            ip-172-31-17-15   v1.34.4   v1.34.7
    kube-proxy                                  1.34.4    v1.34.7
    CoreDNS                                     v1.12.1   v1.12.1
    etcd                      ip-172-31-17-15   3.6.5-0   3.6.5-0


Always take a anspshot of the etcd data before performing an upgrade.

.. code-block:: bash

    etcdctl snapshot save /tmp/etcd-snapshot.db 


Debugging
-----------

 In Kubernetes, the kubectl debug command is used to attach a temporary ephemeral debug container to a running Pod, which is especially useful 
 when the original container (like etcd) has no shell or basic tools. For example:    

.. code-block:: bash

    kubectl debug -n kube-system -it etcd-ip-172-31-17-15 --image=busybox --target=etcd

This starts a BusyBox container with tools like `sh` and `ls`, and because of `--target=etcd`, it joins the same Pod environment as the etcd container. 
That means it shares mounted volumes, so you can inspect directories used by `etcd` even though you are not inside the etcd container itself.

Daemonsets
-------------

Daemonsets are a Kubernetes object that ensures that a copy of a specific Pod is running on all (or some) nodes in the cluster.
This is useful for running cluster-wide services such as log collection, monitoring agents, or network plugins
Get all daemonsets in the cluster

.. code-block:: bash

    kubectl get daemonsets -A

    NAMESPACE     NAME          DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR            AGE

    kube-system   calico-node   3         3         3       3            3           kubernetes.io/os=linux   84d
    kube-system   kube-proxy    3         3         3       3            3           kubernetes.io/os=linux   84d

.. note::

    The ``-A`` flag is used to get resources across all namespaces. 