Persistent Volume (PV)- NFS
============================

In this section, we will set up a Persistent Volume (PV) using NFS. A Persistent Volume is a piece of storage in the cluster that has been provisioned 
by an administrator or dynamically provisioned using Storage Classes. It is a resource in the cluster just like CPU or memory and can be used by 
Pods to store data persistently.

.. code-block:: bash

    sudo mkdir /opt/sfw
    sudo chmod 1777 /opt/sfw/
    sudo chmod 1777 /tmp/
    sudo bash -c 'echo software > /opt/sfw/hello.txt'

The file  `/etc/exports` is used to configure NFS exports on the server. It specifies which directories are shared and the permissions for each client.
Add the following line to the `/etc/exports` file to share the `/opt/sfw` directory with read-write permissions for all clients.

.. code-block:: bash

    /opt/sfw/ *(rw,sync,no_root_squash,subtree_check)


Now, we need to export the shared directory so that it becomes available to clients. This is done using the `exportfs` command, which reads 
the `/etc/exports` file and applies the specified configurations.

.. code-block:: bash

    sudo exportfs -a


Now from one of the **worker nodes**, we can test if the NFS share is accessible by mounting it and checking the contents.

.. code-block:: bash

   showmount -e 172.31.17.15

    Export list for 172.31.17.15:
    /opt/sfw *

Here, **172.31.17.15** is the IP address of the NFS server (control-plane node). The output shows that the `/opt/sfw` directory is exported and accessible 
to all clients.

Now let's mount the NFS share on all the worker node to verify that we can access the files.

.. code-block:: bash

    sudo mount  172.31.17.15:/opt/sfw /mnt

.. code-block:: bash

    ls -l /mnt/
    total 4
    -rw-r--r-- 1 root root 9 May 20 02:34 hello.txt


Now we will create a Persistent Volume (PV) in Kubernetes that points to this NFS share. The PV will be defined in a YAML file `PVol.yaml`:

.. code-block:: yaml

    apiVersion: v1
    kind: PersistentVolume

    metadata:
      name: pvvol-1

    spec:
      capacity:
        storage: 1Gi

      accessModes:
        - ReadWriteMany

      persistentVolumeReclaimPolicy: Retain

      nfs:
        path: /opt/sfw
        server: 172.31.17.15
        readOnly: false

.. code-block:: bash

    kubectl create -f PVol.yaml

    persistentvolume/pvvol-1 created

.. code-block:: bash

    kubectl get pv

    NAME      CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS      CLAIM   STORAGECLASS   VOLUMEATTRIBUTESCLASS   REASON   AGE
    pvvol-1   1Gi        RWX            Retain           Available                          <unset>                          32s

