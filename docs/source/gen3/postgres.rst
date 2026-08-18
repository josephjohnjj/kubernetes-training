GEN3 PostgreSQL
===============

This page documents the PostgreSQL deployment used by GEN3 2025.08. The
database is managed by CloudNativePG and reconciled by the ``gen3-db`` Argo CD
application. GEN3 consumes it as an external PostgreSQL service; the PostgreSQL
subchart bundled with the GEN3 chart is not the durable database used here.

Deployment overview
-------------------

.. list-table::
   :header-rows: 1
   :widths: 30 70

   * - Setting
     - Configured value
   * - Argo CD application
     - ``gen3-db``
   * - Kubernetes namespace
     - ``gen3-db``
   * - CloudNativePG cluster
     - ``gen3-db-cluster``
   * - PostgreSQL image
     - ``ghcr.io/cloudnative-pg/postgresql:13``
   * - Instances
     - 3
   * - Read/write service
     - ``gen3-db-cluster-rw.gen3-db.svc.cluster.local``
   * - Port
     - ``5432``
   * - Storage per instance
     - ``50Gi``
   * - StorageClass
     - ``cnpg-sc``
   * - Initial database
     - ``gen3db``
   * - Initial owner
     - ``gen3db``

The three instances are scheduled with required pod anti-affinity. Kubernetes
must therefore provide three suitable nodes; otherwise one or more database
pods remain ``Pending``. Each instance requests and is limited to 2 CPUs and
``1Gi`` of memory. PostgreSQL ``shared_buffers`` is set to ``512MB``.

High-availability model
-----------------------

CloudNativePG maintains one primary and two replicas. GEN3 services connect to
the ``-rw`` service, which follows the current primary after a switchover or
failover.

::

   GEN3 services
        |
        v
   gen3-db-cluster-rw:5432
        |
        +-- primary PostgreSQL pod
        +-- replica PostgreSQL pod
        +-- replica PostgreSQL pod
                    |
                    v
          3 x 50Gi Ceph RBD PVCs

Pod anti-affinity protects against a single Kubernetes-node failure. The
``cnpg-pool`` also stores three Ceph replicas across hosts. These are different
layers of protection: PostgreSQL replication protects the database service,
while Ceph replication protects each persistent volume.

Persistent storage
------------------

The ``cnpg-sc`` StorageClass dynamically provisions Ceph RBD volumes from the
``cnpg-pool`` using ``rook-ceph.rbd.csi.ceph.com``. Volumes use ``ext4`` and can
be expanded.

The Kubernetes cluster requests ``150Gi`` of logical PostgreSQL capacity across
three PVCs. Physical Ceph consumption is higher because each RBD image is stored
with three replicas.

.. warning::

   ``cnpg-sc`` has a ``Delete`` reclaim policy. Removing a PVC can remove the
   corresponding Ceph RBD image. Do not delete CloudNativePG PVCs as a routine
   troubleshooting step.

Database initialization
-----------------------

When the cluster is created, CloudNativePG ``initdb`` performs the initial
bootstrap:

* Creates the ``gen3db`` database.
* Creates the ``gen3db`` owner from the ``gen3db-secret`` Secret.
* Grants the ``gen3db`` role ``CREATEDB`` and ``CREATEROLE``.
* Enables superuser access using ``superuser-secret``.

The GEN3 Helm release has ``global.postgres.dbCreate: true``. Its database
initialization jobs use the configured PostgreSQL master connection to create
the service databases and credentials when required.

GEN3 databases
--------------

The following service databases are expected by the current configuration:

.. list-table::
   :header-rows: 1
   :widths: 30 35 35

   * - GEN3 service
     - Database
     - Application role
   * - Sheepdog
     - ``sheepdog_gen3``
     - ``gen3db``
   * - Fence
     - ``fence_gen3``
     - ``fence_gen3``
   * - Arborist
     - ``arborist_gen3``
     - ``arborist_gen3``
   * - Audit
     - ``audit_gen3``
     - ``audit_gen3``
   * - Indexd
     - ``indexd_gen3``
     - ``indexd_gen3``
   * - Metadata
     - ``metadata_gen3``
     - ``metadata_gen3``
   * - Peregrine
     - ``peregrine_gen3``
     - ``peregrine_gen3``
   * - WTS
     - ``wts_gen3``
     - ``wts_gen3``

The ``gen3-db-permissions`` Job connects as the database superuser and, for all
eight databases, changes ownership of the ``public`` schema to ``gen3db`` and
grants ``gen3db`` all privileges on that schema.

.. note::

   The permissions Job must run after all service databases exist. It is a
   regular Kubernetes Job rather than an Argo CD hook, so ordering and reruns
   need operational attention. Delete and resync only this Job if it must be
   executed again; do not delete the database cluster or its PVCs.

Connection configuration
------------------------

The GEN3 Helm values configure the shared PostgreSQL endpoint as::

   gen3-db-cluster-rw.gen3-db:5432

The fully qualified form used by some workloads is::

   gen3-db-cluster-rw.gen3-db.svc.cluster.local:5432

Both names address the same CloudNativePG read/write service from inside the
cluster. The global master Secret is named ``postgres-dbcreds`` in the ``gen3``
namespace. Service-specific credentials may be rendered into separate Secrets
or GEN3 configuration Secrets by the Helm chart.

Credentials
-----------

The deployment distinguishes between these credential types:

* ``superuser-secret`` in ``gen3-db``: CloudNativePG superuser credentials.
* ``gen3db-secret`` in ``gen3-db``: owner credentials used during initial
  cluster bootstrap.
* ``postgres-dbcreds`` in ``gen3``: master connection used by GEN3 database
  creation jobs.
* Service credentials in ``gen3``: application access for services such as
  Indexd and Sheepdog.

Never include decoded passwords in documentation, terminal output, ConfigMaps,
or connection strings committed to Git. Production credentials should be
managed through an external secret manager and referenced from Kubernetes
Secrets.

Current manifest ownership
--------------------------

The ``postgres/secrets`` directory contains exactly three infrastructure-owned
Secrets:

* ``01-gen3-owner-secret.yaml`` defines ``gen3db-secret`` in ``gen3-db``.
* ``02-gen3-superuser-secret.yaml`` defines ``superuser-secret`` in ``gen3-db``.
* ``03-postgres-dbcreds.yaml`` defines ``postgres-dbcreds`` in ``gen3``.

Service-specific database Secrets are generated exclusively by the GEN3 Helm
chart. Do not add ``indexd-dbcreds``, ``sheepdog-dbcreds``, or other
service-specific Secrets under ``postgres/secrets`` because that gives two Argo
CD applications ownership of the same Kubernetes object.

Passwords are currently present in repository-managed YAML and GEN3 Helm
values. They should be rotated and migrated to encrypted or external Secrets.
The CloudNativePG backup configuration is also commented out; PostgreSQL
streaming replicas and Ceph replication do not replace backups.

Argo CD reconciliation
----------------------

The ``gen3-db`` Application reads the complete ``postgres`` directory
recursively and targets ``gen3-db``. It enables:

* Automated pruning and self-healing.
* Namespace creation.
* Server-side apply.
* Sync-wave annotation ``1`` on the Argo CD Application.

Some manifests below ``postgres/secrets`` explicitly set their namespace to
``gen3`` and are therefore created there even though the Application destination
is ``gen3-db``.

Routine verification
--------------------

Check the CloudNativePG cluster and pods::

   kubectl -n gen3-db get cluster gen3-db-cluster
   kubectl -n gen3-db get pods -l cnpg.io/cluster=gen3-db-cluster
   kubectl -n gen3-db get svc gen3-db-cluster-rw

Check persistent volumes::

   kubectl -n gen3-db get pvc
   kubectl get storageclass cnpg-sc

Check replication and the primary selected by CloudNativePG::

   kubectl cnpg status gen3-db-cluster -n gen3-db

If the ``kubectl cnpg`` plugin is unavailable, inspect the cluster status::

   kubectl -n gen3-db get cluster gen3-db-cluster -o yaml

List databases without printing passwords::

   kubectl -n gen3-db exec -it gen3-db-cluster-1 -- \
     psql -U postgres -d postgres -c '\\l'

Review initialization and permission jobs::

   kubectl -n gen3 get jobs
   kubectl -n gen3-db get job gen3-db-permissions
   kubectl -n gen3-db logs job/gen3-db-permissions

Backup requirements
-------------------

The manifest includes an example Barman object-store backup section, but it is
commented out. Before production use, configure and test:

* Scheduled base backups.
* Continuous WAL archiving.
* A retention policy appropriate for the recovery objectives.
* Object storage credentials supplied through a Secret.
* Restore into a separate test cluster.
* Monitoring and alerts for failed backups and excessive replication lag.

A database is not considered recoverable until a restore has been tested.

Common troubleshooting
----------------------

Pods remain Pending
~~~~~~~~~~~~~~~~~~~

Confirm that three schedulable nodes satisfy required anti-affinity and that
``cnpg-sc`` can provision Ceph RBD volumes::

   kubectl -n gen3-db describe pod <pending-pod>
   kubectl -n gen3-db describe pvc <pending-pvc>

GEN3 cannot connect
~~~~~~~~~~~~~~~~~~~

Verify the read/write service, endpoints, and DNS from the GEN3 namespace::

   kubectl -n gen3-db get svc,endpoints gen3-db-cluster-rw
   kubectl -n gen3 run postgres-dns-check --rm -it --restart=Never \
     --image=busybox:1.36 -- \
     nslookup gen3-db-cluster-rw.gen3-db.svc.cluster.local

Do not put passwords directly on a command line while testing connectivity;
read them from the appropriate Secret inside a temporary, controlled pod.

Permissions Job fails
~~~~~~~~~~~~~~~~~~~~~

Check whether every expected database exists first. The Job exits on its first
SQL error because its script uses ``set -e``. If a database is missing, allow
the GEN3 database-creation job to complete, then rerun only the permissions Job.
