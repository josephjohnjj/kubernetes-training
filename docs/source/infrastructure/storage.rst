Rook-Ceph Storage
==========================


The Kubernetes control plane and worker nodes have already been deployed and joined to the cluster. HAProxy has been configured on the login node. 
All installation and management tasks in this guide are performed from a control plane node.



Storage Node Design
--------------------

The storage nodes are dedicated to Ceph and should not run application workloads.

Only the storage nodes should host:

* Ceph MONs
* Ceph MGRs
* Ceph OSDs

Ceph MONs, MGRs, and OSDs are the three core building blocks of a Ceph cluster, each playing a different role. The MONs (Monitors) are responsible 
for maintaining the overall health and state of the cluster. They keep track of which nodes are alive, manage the cluster maps (like the CRUSH map 
and OSD map), and ensure consensus through a quorum—usually requiring at least three MONs for high availability. Without MONs forming a quorum, 
the cluster cannot safely make decisions, which can impact operations even if storage is still physically available.

Ceph MGRs (Managers) act as the control and observability layer of the system. They do not store any data but provide cluster metrics, health 
dashboards, and APIs that tools like the Ceph Dashboard and Prometheus rely on. Typically, one MGR is active while another remains on standby 
to provide redundancy, ensuring continuous monitoring and management capabilities even if one manager fails.

Ceph OSDs (Object Storage Daemons) are where the actual data lives. Each OSD manages a physical disk (or partition) and is responsible for reading, 
writing, replicating, and recovering data across the cluster. They also report their status back to the MONs. In your setup, the three storage nodes 
will host the OSDs, and Ceph will replicate data across them (for example with a replication size of three) to ensure durability and fault tolerance 
even if a node goes down.





Add Rook Helm Repository
---------------------------------

Add the Rook repository:

.. code-block:: bash

   helm repo add rook-release https://charts.rook.io/release
   helm repo update

Install the Rook Operator
---------------------------------


Install the Rook operator and create the nampace rook-ceph:

.. code-block:: bash

   helm install --create-namespace --namespace rook-ceph rook-ceph rook-release/rook-ceph -f https://raw.githubusercontent.com/rook/rook/master/deploy/charts/rook-ceph/values.yaml

Install the ceph-csi-drivers

.. code-block:: bash

   helm install ceph-csi-drivers --namespace rook-ceph ceph-csi-operator/ceph-csi-drivers   -f https://raw.githubusercontent.com/rook/rook/master/deploy/charts/ceph-csi-drivers/values.yaml


Verify the deployment:

.. code-block:: bash

    kubectl -n rook-ceph get pods

   NAME                                           READY   STATUS    RESTARTS   AGE
   ceph-csi-controller-manager-67dc6f9fd7-q77g4   1/1     Running   0          110s
   rook-ceph-operator-7f69df8d5-z77pn             1/1     Running   0          110s

Wait until all pods are in the ``Running`` state.

 Deploy the Ceph Cluster
-------------------------------

Log in to each storage node and identify available disks:

.. code-block:: bash


   lsblk

   NAME         MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
 
   nvme2n1      259:0    0  200G  0 disk 
   nvme3n1      259:1    0  200G  0 disk 
   nvme1n1      259:2    0  200G  0 disk 
   nvme0n1      259:3    0  100G  0 disk 
   ├─nvme0n1p1  259:4    0 99.9G  0 part /
   ├─nvme0n1p14 259:5    0    4M  0 part 
   └─nvme0n1p15 259:6    0  106M  0 part /boot/efi



Remove any existing filesystem signatures from the disks that will be used by Ceph:

.. code-block:: bash

   wipefs -a /dev/nvme1n1
   wipefs -a /dev/nvme2n1
   wipefs -a /dev/nvme3n1

.. warning::

   Never wipe the operating system disk.


Create ``cluster.yaml`` in :file:`infrastructure/ansible/3_rook/manifest/cluster.yaml`


This YAML defines a Rook Ceph `CephCluster` resource, which tells Kubernetes how to deploy and configure a Ceph storage cluster inside a namespace 
called `rook-ceph`. It specifies that Ceph version 19 should be used via a container image, and that all cluster data should be stored on the host 
at `/var/lib/rook`. The cluster is configured to run three monitor (`mon`) nodes for quorum and high availability, with a rule that prevents 
multiple monitors from running on the same node, and two manager (`mgr`) pods to handle cluster operations and the dashboard, which is explicitly 
enabled for web-based monitoring. On the storage side, automatic device discovery is disabled (`useAllNodes` and `useAllDevices` are false), meaning 
disks are explicitly assigned to specific nodes. Three storage nodes (`storage1`, `storage2`, and `storage3`) are defined, and each node is given 
three NVMe devices (`/dev/nvme1n1`, `/dev/nvme2n1`, `/dev/nvme3n1`) to be used as Ceph OSDs, giving the cluster controlled, predictable storage 
placement across dedicated hardware.



.. note::

   If both `useAllNodes: true` and `useAllDevices: true` are enabled in a Rook Ceph `CephCluster`, you are essentially telling Rook to **automatically 
   discover and use all available storage across the entire cluster without manual selection**.

   With `useAllNodes: true`, Rook will schedule storage (OSDs) on **every eligible Kubernetes node** in the cluster instead of only the specific 
   nodes you list under `spec.storage.nodes`. At the same time, `useAllDevices: true` instructs it to **automatically consume all unformatted, 
   unused block devices (like empty disks or NVMe drives)** on those nodes.

   In practice, this means Ceph will aggressively take over all suitable disks across all nodes and turn them into storage devices for the cluster. 
   This is convenient for lab setups or simple environments because it requires almost no manual configuration, but it can be risky in production: 
   any accidentally attached disk (even one you intended for something else) could be claimed and wiped by Ceph. It also reduces control over data 
   placement, since you no longer explicitly decide which nodes or disks are used.



Apply the configuration:

.. code-block:: bash

   kubectl apply -f cluster.yaml

.. code-block:: bash

   kubectl -n rook-ceph get cephcluster

   NAME        DATADIRHOSTPATH   MONCOUNT   AGE   PHASE   MESSAGE                        HEALTH        EXTERNAL   FSID
   rook-ceph   /var/lib/rook     3          19m   Ready   Cluster created successfully   HEALTH_WARN              99d2231e-112c-4508-b357-9b6c7ec66d6c


Ceph Toolbox
--------------------


The **Rook Ceph Toolbox** (often created as a `CephToolbox` or `ceph-tools` pod) is a **debug and 
administration utility pod** that runs inside your Kubernetes cluster and provides direct access to 
Ceph management commands. Instead of installing Ceph CLI tools on your local machine or control plane 
node, the toolbox gives you a ready-made environment that already contains utilities like `ceph`, 
`rbd`, and `cephfs` tools, configured to connect automatically to your running Ceph cluster.

Once deployed, the toolbox runs as a normal Kubernetes pod in the `rook-ceph` namespace. You typically 
access it using `kubectl exec`, and from inside the pod you can run commands such as `ceph status`, 
`ceph osd tree`, `ceph df`, or troubleshoot pool and cluster health issues. Because it is inside the 
cluster network and has the correct configuration files mounted, it can communicate directly with the 
Ceph monitors and managers without extra setup.

.. note::

   The key idea is that the toolbox is **not part of the storage cluster itself** (it doesn't store 
   data or run OSDs, MONs, or MGRs). Instead, it is a diagnostic and operational companion tool
   used for debugging, inspection, and manual administration. 


Create ``toolbox.yaml`` in :file:`infrastructure/ansible/3_rook/manifest/toolbox.yaml`

Apply the manifest:

.. code-block:: bash

   kubectl apply -f toolbox.yaml

Verify:

.. code-block:: bash

   kubectl -n rook-ceph get pods

   ...
   ...

   rook-ceph-tools-5548d6845b-c92j4                          1/1     Running     0          3m14s


Now, open a shell in the toolbox pod:

.. code-block:: bash

   kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- bash

Check cluster status:

.. code-block:: bash

   ceph status

   cluster:
     id:     70d57535-e445-4cf4-a3da-e5eeca02ae23
     health: HEALTH_OK
   
   services:
     mon: 3 daemons, quorum a,b,c (age 4h)
     mgr: a(active, since 4h), standbys: b
     osd: 9 osds: 9 up (since 10m), 9 in (since 10m)
   
   data:
     pools:   1 pools, 1 pgs
     objects: 2 objects, 577 KiB
     usage:   241 MiB used, 1.8 TiB / 1.8 TiB avail
     pgs:     1 active+clean



Check OSD status:

.. code-block:: bash

   ceph osd status

   ID  HOST       USED  AVAIL  WR OPS  WR DATA  RD OPS  RD DATA  STATE      
    0  storage1  26.6M   199G      0        0       0        0   exists,up  
    1  storage2  26.5M   199G      0        0       0        0   exists,up  
    2  storage3  26.6M   199G      0        0       0        0   exists,up  
    3  storage1  27.1M   199G      0        0       0        0   exists,up  
    4  storage2  26.5M   199G      0        0       0        0   exists,up  
    5  storage3  27.1M   199G      0        0       0        0   exists,up  
    6  storage1  26.6M   199G      0        0       0        0   exists,up  
    7  storage2  27.1M   199G      0        0       0        0   exists,up  
    8  storage3  26.6M   199G      0        0       0        0   exists,up 

or:

.. code-block:: bash

   ceph osd tree

   ID  CLASS  WEIGHT   TYPE NAME          STATUS  REWEIGHT  PRI-AFF
   -1         1.75768  root default                                
   -3         0.58589      host storage1                           
    0   nvme  0.19530          osd.0          up   1.00000  1.00000
    3   nvme  0.19530          osd.3          up   1.00000  1.00000
    6   nvme  0.19530          osd.6          up   1.00000  1.00000
   -5         0.58589      host storage2                           
    1   nvme  0.19530          osd.1          up   1.00000  1.00000
    4   nvme  0.19530          osd.4          up   1.00000  1.00000
    7   nvme  0.19530          osd.7          up   1.00000  1.00000
   -7         0.58589      host storage3                           
    2   nvme  0.19530          osd.2          up   1.00000  1.00000
    5   nvme  0.19530          osd.5          up   1.00000  1.00000
    8   nvme  0.19530          osd.8          up   1.00000  1.00000

Verify that all storage nodes are present.


File System
-------------------


Create ``scratch-fs.yaml`` in :file:`infrastructure/ansible/3_rook/manifest/scratch-fs.yaml`



Apply the configuration:

.. code-block:: bash

   kubectl apply -f scratch-fs.yaml

.. code-block:: bash

   kubectl -n rook-ceph get cephfilesystem 

   NAME         ACTIVEMDS   AGE   PHASE
   scratch-fs   1           71m   Ready



Storage Class
-------------------


Create ``scratch-sc.yaml`` in :file:`infrastructure/ansible/3_rook/manifest/scratch-sc.yaml`



.. code-block:: bash

   kubectl apply -f scratch-sc.yaml

Verify:

.. code-block:: bash

   kubectl get storageclass -n ceph-rook

   NAME         PROVISIONER                     RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
   scratch-sc   rook-ceph.cephfs.csi.ceph.com   Delete          Immediate           false                  35m


Make the Ceph StorageClass the default (optional):

.. code-block:: bash

   kubectl patch storageclass scratch-sc \
     -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'



Persistant Volume Claim
-------------------------

First create a namspace `mlproject`.

.. code-block:: bash

   kubectl create ns mlproject


Create ``mlproject-pvc.yaml`` in :file:`infrastructure/ansible/3_rook/manifest/mlproject-pvc.yaml`



   kubectl apply -f mlproject-pvc.yaml

Verify:

.. code-block:: bash

   kubectl get pvc -n mlproject
   
   NAME            STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
   mlproject-pvc   Bound    pvc-fc8373b4-e0d4-4feb-b228-53f9d3392b46   20Gi       RWX            scratch-sc     <unset>                 38m

