Backup etcd Database
================

It is always a good idea to backup the cluster state prior to upgrading it.

 Find the data directory of the etcddaemon. All of the settings for the pod can be found in the manifest


.. code-block:: bash

  sudo grep data-dir /etc/kubernetes/manifests/etcd.yaml

This should output something like this: 

.. code-block:: bash

        - --data-dir=/var/lib/etcd

Now find the etcd container

.. code-block:: bash

    kubectl get pods -n kube-system 

    kubectl get pods -n kube-system | grep etcd

.. note::

    `-n` stands for `--namespace`. Kubernetes uses namespaces to organize and manage resources. 
    The `kube-system` namespace is a special namespace that contains the core components of the Kubernetes cluster, 
    including the etcd database. By specifying `-n kube-system`, you are telling `kubectl` to look for pods in the `kube-system`
    namespace, which is where the etcd pod is running. This allows you to easily find and interact with the etcd pod without having to 
    search through all namespaces in the cluster.


Now log into the etcd container

.. code-block:: bash

    kubectl exec -n kube-system -it etcd-ip-172-31-17-15 -- sh


.. note::

    `kubectl exec` is a command that allows you to run a command inside a container in a Kubernetes pod. 
    The `-n kube-system` flag specifies that the pod is in the `kube-system` namespace, which is where the etcd pod is located. 
    The `-it` flags are used to run the command in an interactive terminal, allowing you to interact with the shell inside the container. 
    Finally, `-- sh` specifies that you want to open a shell inside the container, giving you access to the command line interface of the etcd container. 
    This can be useful for troubleshooting, inspecting logs, or performing maintenance tasks on the etcd database.


In most cases this will not work as etcd is running on a minimal image that does not have a shell. 

.. code-block:: bash

    error: Internal error occurred: Internal error occurred: error executing command in container: failed to exec in container: failed to start exec "68fea83facc5c2c4e944a00934c705fe55fc6d93ffd09caf5d0734bb9ff6211e": OCI runtime exec failed: exec failed: unable to start container process: exec: "sh": executable file not found in $PATH


One way to overcome this to attach a temporary ephemeral debug container to the etcd pod. This will allow us to run commands in the same 
network namespace as the etcd container, giving us access to the etcd data directory.


.. code-block:: bash

    kubectl debug -n kube-system -it etcd-ip-172-31-17-15 --image=busybox --target=etcd


So we can directly execute the etcdctl command without logging into the container. In this case, that is also not possible 
as the etcd pod is a static pod. 

.. note::

    A static Pod in Kubernetes is a Pod that is managed directly by the kubelet on a specific node, rather than by the Kubernetes 
    API server (which is how normal Pods are managed).


So we run the commands directly without logging into the container. This is especially useful when the original container does not have a shell or 
basic tools, allowing you to troubleshoot and inspect the environment effectively.

First we check the health of the etcd cluster. This will give us an indication of whether the cluster is healthy and functioning properly.

.. code-block:: bash

     kubectl -n kube-system exec -it etcd-ip-172-31-17-15 -- \
        etcdctl \
        --endpoints=https://127.0.0.1:2379 \
        --cacert=/etc/kubernetes/pki/etcd/ca.crt \
        --cert=/etc/kubernetes/pki/etcd/server.crt \
        --key=/etc/kubernetes/pki/etcd/server.key \
        endpoint health




     kubectl -n kube-system exec -it etcd-ip-172-31-17-15 -- \
        etcdctl \
        --cacert=/etc/kubernetes/pki/etcd/ca.crt \
        --cert=/etc/kubernetes/pki/etcd/server.crt \
        --key=/etc/kubernetes/pki/etcd/server.key \
        endpoint health


We should get a healthy response from the etcd cluster:

.. code-block:: bash
    
   https://127.0.0.1:2379 is healthy: successfully committed proposal: took = 9.517204ms


Determine how many databases are part of the cluster.


.. code-block:: bash

    kubectl -n kube-system exec -it etcd-ip-172-31-17-15 -- etcdctl 
        --endpoints=https://127.0.0.1:2379 \
        --cacert=/etc/kubernetes/pki/etcd/ca.crt \
        --cert=/etc/kubernetes/pki/etcd/server.crt \
        --key=/etc/kubernetes/pki/etcd/server.key member list


    kubectl -n kube-system exec -it etcd-ip-172-31-17-15 -- etcdctl 
        --endpoints=https://127.0.0.1:2379 \
        --cacert=/etc/kubernetes/pki/etcd/ca.crt \
        --cert=/etc/kubernetes/pki/etcd/server.crt \
        --key=/etc/kubernetes/pki/etcd/server.key member list -w table


The second command provides a more human-readable output, showing the member ID, status, name, peer URLs, and client URLs in a tabular format.


.. code-block:: bash

    +------------------+---------+-----------------+---------------------------+---------------------------+------------+
    |        ID        | STATUS  |      NAME       |        PEER ADDRS         |       CLIENT ADDRS        | IS LEARNER |
    +------------------+---------+-----------------+---------------------------+---------------------------+------------+
    | 3fc013ee4480b0d0 | started | ip-172-31-17-15 | https://172.31.17.15:2380 | https://172.31.17.15:2379 |      false |
    +------------------+---------+-----------------+---------------------------+---------------------------+------------+


.. note::

    Here peer address is used for communication between etcd members, while client address is used for communication between etcd and its 
    clients (like the Kubernetes API server).

No we can create a snapshot of the etcd data. 

.. code-block:: bash

    kubectl -n kube-system exec -it etcd-ip-172-31-17-15 -- \
        etcdctl \
        --endpoints=https://127.0.0.1:2379 \
        --cacert=/etc/kubernetes/pki/etcd/ca.crt \
        --cert=/etc/kubernetes/pki/etcd/server.crt \
        --key=/etc/kubernetes/pki/etcd/server.key \
        snapshot save /var/lib/etcd/snapshot.db


Verify that the snapshot was created successfully by listing the contents of the data directory.

.. code-block:: bash

    sudo ls -l /var/lib/etcd/

.. note::

    Ideally, this snasphsot should be stored in a safe location outside of the cluster, such as an object storage service or a backup server, 
    to ensure that it can be retrieved and used for recovery in case of a cluster failure or data losss.





    



