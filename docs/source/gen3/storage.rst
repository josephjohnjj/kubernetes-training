GEN3 Storage
============

This page describes the storage components configured for the GEN3 2025.08
deployment. It is based on the manifests in ``storage/rook-ceph``, ``postgres``,
``charts/eck-stack``, and ``charts/gen3-2025.08``.

Storage architecture
--------------------

The deployment uses Rook-Ceph as its storage foundation. Ceph provides two
storage interfaces to GEN3:

* RADOS Block Device (RBD) volumes for PostgreSQL and Elasticsearch.
* S3-compatible object storage through the Ceph Object Gateway (RGW) for GEN3
  buckets and an optional Fence UserSync source.

The GEN3 application pods themselves are mostly stateless. Durable application
data is held by CloudNativePG, Elasticsearch, or Ceph RGW rather than in the
pods' container filesystems.

::

   GEN3 services
      +-- CloudNativePG PostgreSQL -- PVC (cnpg-sc) -----------------+
      +-- Elasticsearch ---------- PVC (gen3-elasticsearch-sc) -----+--> Rook-Ceph
      +-- Optional Fence UserSync - S3 (gen3-store/users-bucket) ----+

Rook-Ceph cluster
-----------------

The ``rook-ceph`` cluster is deployed in the ``rook-ceph`` namespace. Its
storage layout is explicitly defined rather than using every node and disk:

* Ceph image: ``quay.io/ceph/ceph:v20.2.1``
* Monitor daemons: 3
* Manager daemons: 2
* Storage nodes: ``storage1``, ``storage2``, and ``storage3``
* Devices per storage node: ``nvme1n1``, ``nvme2n1``, and ``nvme3n1``
* Total configured OSD devices: 9
* Ceph host data directory: ``/var/lib/rook``

The block pools and object-store pools used by GEN3 replicate data three ways.
Their failure domain is the host where specified, spreading RBD replicas across
storage nodes.

PostgreSQL storage
------------------

GEN3 uses a CloudNativePG ``Cluster`` named ``gen3-db-cluster`` in the
``gen3-db`` namespace. It has three PostgreSQL 13 instances. Each instance
requests a ``50Gi`` persistent volume, so the cluster requests ``150Gi`` of
logical Kubernetes volume capacity before Ceph replication overhead.

The database volumes use the following storage path:

* StorageClass: ``cnpg-sc``
* CSI provisioner: ``rook-ceph.rbd.csi.ceph.com``
* Ceph block pool: ``cnpg-pool``
* Filesystem: ``ext4``
* Volume expansion: enabled
* Reclaim policy: ``Delete``

GEN3 connects to the read/write service at
``gen3-db-cluster-rw.gen3-db:5432``. The database cluster provides durable
storage for services including Fence, Indexd, Sheepdog, Arborist, Audit,
Metadata, Peregrine, and WTS.

.. warning::

   The StorageClass reclaim policy is ``Delete``. Deleting a PostgreSQL PVC can
   delete its underlying Ceph RBD image. The backup section in the current
   CloudNativePG manifest is commented out, so an external backup and restore
   procedure must be established before treating this as production storage.

Elasticsearch storage
---------------------

The ECK-managed ``elasticsearch`` resource runs in the ``elasticsearch``
namespace. It currently has one Elasticsearch node with one ``100Gi``
``ReadWriteOnce`` persistent volume.

The Elasticsearch volume uses:

* StorageClass: ``gen3-elasticsearch-sc``
* CSI provisioner: ``rook-ceph.rbd.csi.ceph.com``
* Ceph block pool: ``gen3-elasticsearch-pool``
* Pool replica count: 3, with ``host`` as the failure domain
* Filesystem: ``ext4``
* Volume expansion: enabled
* Reclaim policy: ``Delete``
* Binding mode: ``Immediate``

Guppy reads indexed data from Elasticsearch, while the Tube ETL process writes
the ``dev_case`` and ``dev_case-array-config`` indices. Kibana is deployed as a
frontend but does not have a persistent volume in this configuration.

.. note::

   Ceph protects the Elasticsearch volume from a disk or storage-node failure,
   but the single Elasticsearch node is still an application-level availability
   limitation. Elasticsearch snapshots are not configured in the manifests
   reviewed for this page.

Ceph S3 object storage
----------------------

The ``CephObjectStore`` named ``gen3-store`` runs in ``rook-ceph``. It has one
RGW gateway instance listening on port 80. Both its metadata and data pools use
three replicas, and ``preservePoolsOnDelete`` is enabled.

The in-cluster S3 endpoint is::

   http://rook-ceph-rgw-gen3-store.rook-ceph.svc:80

The ``gen3-bucket`` StorageClass provisions object buckets from this store. Its
reclaim policy is ``Retain``, so bucket data is retained when an
``ObjectBucketClaim`` is deleted.

Two statically named ObjectBucketClaims are defined in the ``gen3`` namespace:

* ``users-bucket``: can store ``users.yaml`` for Fence UserSync.
* ``schema-bucket``: reserved for GEN3 schema objects; the current
  ``global.dictionaryUrl`` still points to the external GEN3 dictionary URL.

The active POC sets ``userYamlS3Path: "none"`` and uses the ``USER_YAML``
embedded in the Fence chart. The S3 configuration is retained as a commented
future option. When enabled, Fence reads ``s3://users-bucket/users.yaml``
through the RGW endpoint and requires credentials that can read that exact
bucket and object. Rook supplies OBC credentials through the ``users-bucket``
Secret. Uploading an object with credentials belonging to an older retained
bucket does not grant a newly provisioned OBC identity access to it.

.. warning::

   Do not place decoded S3 keys, database passwords, or Elasticsearch passwords
   in this documentation. Store credentials in Kubernetes Secrets or an
   external secret manager and reference them from Helm values.

Ephemeral pod storage
---------------------

ConfigMaps, Secrets, and configuration-only volume mounts used by GEN3 services
do not provide durable data storage. No general-purpose GEN3 application PVC is
configured by the ``gen3-2025.08`` chart. If a pod writes data outside the
PostgreSQL, Elasticsearch, or S3 paths described above, that data should be
treated as ephemeral.

Argo CD ownership
-----------------

Storage is reconciled separately from the GEN3 application:

* ``rook-ceph-cluster`` manages the Ceph cluster.
* ``rook-ceph-storage`` manages pools, filesystems, StorageClasses, the object
  store, users, and bucket claims.
* ``gen3-db`` manages the CloudNativePG database resources.
* ``elasticsearch`` manages the ECK Elasticsearch and Kibana resources.
* ``gen3`` deploys the GEN3 2025.08 services and connects them to those storage
  endpoints.

Verification
------------

Use these read-only checks after an Argo CD sync::

   kubectl -n rook-ceph get cephcluster,cephblockpool,cephobjectstore
   kubectl get storageclass cnpg-sc gen3-elasticsearch-sc gen3-bucket
   kubectl -n gen3-db get clusters.postgresql.cnpg.io,pvc,pod
   kubectl -n elasticsearch get elasticsearch,pvc,pod
   kubectl -n gen3 get objectbucketclaim
   kubectl -n rook-ceph get cephobjectstoreuser gen3-usersync

Expected checks are that the Ceph cluster is healthy, the PostgreSQL cluster has
three ready instances, the Elasticsearch PVC is ``Bound``, and both bucket
claims are ``Bound``.
