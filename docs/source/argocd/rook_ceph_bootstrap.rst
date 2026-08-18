Manual Rook-Ceph Bootstrap and Argo CD Handoff
==============================================

Rook-Ceph was initially created manually. Argo CD now tracks equivalent
operator, CSI, cluster, storage, and toolbox resources, but automatic pruning
and self-healing are disabled for all five Rook-Ceph Applications.

Initial manual installation
---------------------------

The Helm repositories and operator components were installed with::

   helm repo add rook-release https://charts.rook.io/release
   helm repo add ceph-csi-operator https://ceph.github.io/ceph-csi-operator
   helm repo update

   helm install --create-namespace --namespace rook-ceph \
     rook-ceph rook-release/rook-ceph \
     -f https://raw.githubusercontent.com/rook/rook/master/deploy/charts/rook-ceph/values.yaml

   helm install ceph-csi-drivers --namespace rook-ceph \
     ceph-csi-operator/ceph-csi-drivers \
     -f https://raw.githubusercontent.com/rook/rook/master/deploy/charts/ceph-csi-drivers/values.yaml

   kubectl get csidrivers

.. warning::

   These historical commands use mutable ``master`` files and do not pin chart
   versions. For a rebuild, use the vendored charts and values managed by Argo
   CD, or record exact upstream chart versions and checksums.

Create the Ceph cluster
-----------------------

The cluster was then created from ``cluster.yaml`` and verified::

   kubectl create -f cluster.yaml
   kubectl -n rook-ceph get cephcluster

The Git-managed equivalent is
``storage/rook-ceph/cluster/01-rook-ceph-cluster.yaml``. It explicitly uses three storage
nodes and nine NVMe devices. Confirm every device is empty before applying it.

Install operational tools
-------------------------

The toolbox and dashboard access were created manually::

   kubectl create -f tools/rook-ceph/01-toolbox.yaml
   kubectl -n rook-ceph get service

The Git-managed equivalents are ``tools/rook-ceph/01-toolbox.yaml`` and
``tools/rook-ceph/02-dashboard.yaml``.

Retrieve the generated dashboard password only when needed::

   kubectl -n rook-ceph get secret rook-ceph-dashboard-password \
     -o jsonpath="{['data']['password']}" | base64 --decode
   echo

.. warning::

   A dashboard password was previously included in installation notes. Treat it
   as exposed, rotate it, and never commit or reproduce it in documentation.

Restarting the operator
-----------------------

The operator was restarted during setup with::

   kubectl -n rook-ceph delete pod -l app=rook-ceph-operator

The Deployment recreates the pod. Use this only after inspecting operator logs
and confirming a restart is necessary; it is not a normal installation step.

Create filesystem storage
-------------------------

Scratch CephFS and its StorageClass were initially created manually::

   kubectl create -f storage/rook-ceph/storage/cephfilesystem/02-scratch-fs.yaml
   kubectl -n rook-ceph get cephfilesystem
   kubectl create -f storage/rook-ceph/storage/storageclasses/06-scratch-sc.yaml
   kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph fs ls
   kubectl create namespace mlproject

Their repository equivalents are under
``storage/rook-ceph/storage/cephfilesystem`` and
``storage/rook-ceph/storage/storageclasses``. The ``mlproject`` namespace and
PVC are also represented under ``argocd/applications/mlprojects``.

Argo CD ownership after handoff
-------------------------------

.. list-table::
   :header-rows: 1
   :widths: 30 40 30

   * - Application
     - Git source
     - Responsibility
   * - ``rook-ceph``
     - ``charts/rook-ceph``
     - Rook operator and CRDs
   * - ``rook-ceph-csi``
     - ``charts/ceph-csi-drivers``
     - Ceph CSI drivers
   * - ``rook-ceph-cluster``
     - ``storage/rook-ceph/cluster``
     - CephCluster topology and devices
   * - ``rook-ceph-storage``
     - ``storage/rook-ceph/storage``
     - Pools, filesystems, classes, and object storage
   * - ``rook-ceph-tools``
     - ``tools/rook-ceph``
     - Toolbox and dashboard Service

Because these Applications have ``prune: false`` and ``selfHeal: false``, Argo
CD does not automatically reverse manual changes. A human must inspect the diff
and explicitly sync. This is a deliberate safety boundary for storage.

Handoff verification
--------------------

Before considering the manual installation adopted by GitOps::

   kubectl -n argocd get application \
     rook-ceph rook-ceph-csi rook-ceph-cluster rook-ceph-storage rook-ceph-tools
   argocd app diff rook-ceph
   argocd app diff rook-ceph-cluster
   argocd app diff rook-ceph-storage
   kubectl -n rook-ceph get cephcluster,cephfilesystem,cephblockpool
   kubectl -n rook-ceph exec deploy/rook-ceph-tools -- ceph status

Do not force synchronization of a CephCluster until differences in node names,
device lists, image versions, and storage pools have been reviewed.
