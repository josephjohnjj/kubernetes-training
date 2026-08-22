Argo CD Management Architecture
===============================

This repository uses the app-of-apps pattern. Argo CD is installed first, then
two root Applications discover the platform and workload Applications stored
in Git.

::

   Manual Argo CD installation
              |
              v
   argocd/bootstrap
      +-- AppProject: infrastructure
      +-- Application: infrastructure ----> argocd/infrastructure
      +-- Application: applications ------> argocd/applications
                                                  |
                          +-----------------------+------------------+
                          v                                          v
                  platform Applications                  GEN3 database/workloads
                          |                                          |
               charts, storage, tools,                postgres and
                    and kueue                         charts/gen3-2025.08

Bootstrap resources
-------------------

``argocd/bootstrap/01-project-infrastructure.yaml`` defines the
``infrastructure`` AppProject, allowed source repositories, destination
namespaces, and permitted resource kinds.

``argocd/bootstrap/03-infrastructure.yaml`` recursively reads
``argocd/infrastructure``. It creates the child Applications for storage,
databases, networking, observability, security, and scheduling.

The ``platform-ingresses`` child Application reads ``argocd/ingresses`` and
owns the Argo CD, Ceph dashboard, Grafana, Jaeger, Keycloak, and OpenSearch
Dashboard ingress resources. The hostnames currently use the environment's
``44.203.188.20.nip.io`` address and must be changed if the ingress endpoint
changes.

All six public ingresses use cert-manager production certificates and force
HTTP-to-HTTPS redirects. Argo CD uses HTTPS to its backend Service; the other
components terminate TLS at ingress-nginx and use their configured
cluster-local backend protocol. See :doc:`../configuration/ingress_nginx` for
the component matrix and certificate verification procedure.

``argocd/bootstrap/04-applications.yaml`` recursively reads
``argocd/applications``. It creates the GEN3 database at sync wave ``10`` and
the GEN3 workload at sync wave ``20``, keeping both under the same parent so
their ordering is enforced.

Sync-wave order
---------------

The infrastructure tree uses dependency-based waves. Namespaces start at
``-20``; operators and foundational controllers use ``-10``; CSI and
Prometheus use ``-9``; Ceph and other dependent services progress through
``-8`` to ``-4``; and platform ingresses use ``10``. The applications tree
then reconciles ``gen3-db`` at ``10``, ``gen3`` at ``20``, and the test
``small-llm`` workload at ``30``.

Reconciliation behavior
-----------------------

Each child Application declares:

* A Git or Helm source.
* A repository revision, normally ``main``.
* A source path or external chart.
* A destination namespace.
* Helm values or recursive directory behavior.
* Whether automated pruning and self-healing are enabled.

When both ``prune`` and ``selfHeal`` are true, Argo CD restores drift and
removes objects deleted from Git. Several foundational Applications—including
Rook-Ceph, Ceph CSI, the Ceph cluster, tools, ingress-nginx, and some databases—
set both options to false. Argo CD displays their differences but does not
automatically correct or delete resources.

.. warning::

   ``Synced`` means the live manifests match the desired manifests. It does not
   prove that storage is healthy, a database has quorum, or an application is
   usable. Always check workload readiness after synchronization.

Change workflow
---------------

#. Change a manifest or Helm values file in a source directory.
#. Render or validate it locally.
#. Commit and push the change to the tracked branch.
#. Inspect the Argo CD diff.
#. Sync manually when automation is disabled, or observe automated sync.
#. Verify controllers, pods, services, persistent volumes, and application
   behavior.

Useful commands::

   kubectl -n argocd get applications
   kubectl -n argocd get application <application-name> -o wide
   argocd app get <application-name>
   argocd app diff <application-name>
   argocd app sync <application-name>

Manual management boundaries
----------------------------

Two important parts were initially configured manually:

* The Keycloak OIDC client Secret and ``argocd-cm`` OIDC settings.
* The initial Rook-Ceph operator, CSI drivers, CephCluster, toolbox, filesystem,
  and StorageClass installation.

The current repository now contains Argo CD Applications for the Rook-Ceph
resources, but their automated pruning and self-healing are disabled. The
Keycloak OIDC connection remains a manual cluster configuration; only Argo CD
RBAC policy is stored in Git.
