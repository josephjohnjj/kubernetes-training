Repository Paths Managed by Argo CD
===================================

Argo CD Application definitions live under ``argocd`` while their desired
resources are stored across several top-level directories.

``argocd``
----------

This is the control layer:

* ``argocd/bootstrap`` contains the AppProject, root Applications, and Argo CD
  RBAC ConfigMap.
* ``argocd/infrastructure`` contains child Applications for platform services.
* ``argocd/applications`` contains workload Applications such as GEN3.
* ``argocd/ingresses`` contains the platform ingress resources reconciled by
  the ``platform-ingresses`` Application.
* ``argocd/infrastructure/01-namespace.yaml`` declares platform namespaces and is
  applied by the recursive infrastructure root Application.

The root Applications monitor these directories and create or update their
child ``Application`` objects.

``charts``
----------

Most platform software is vendored as Helm charts. Child Applications select a
chart path and, where needed, a repository-specific values file.

.. list-table::
   :header-rows: 1
   :widths: 30 40 30

   * - Argo CD Application
     - Source path
     - Namespace
   * - ``rook-ceph``
     - ``charts/rook-ceph``
     - ``rook-ceph``
   * - ``rook-ceph-csi``
     - ``charts/ceph-csi-drivers``
     - ``rook-ceph``
   * - ``cnpg-operator``
     - ``charts/cloudnative-pg``
     - ``cnpg-system``
   * - ``cnpg-database``
     - ``charts/cloudnative-pg-cluster``
     - ``cnpg-database``
   * - ``elasticsearch-operator``
     - ``charts/eck-operator``
     - ``elasticsearch``
   * - ``elasticsearch``
     - ``charts/eck-stack``
     - ``elasticsearch``
   * - ``ingress-nginx``
     - ``charts/ingress-nginx``
     - ``ingress-nginx``
   * - ``prometheus``
     - ``charts/prometheus-stack``
     - ``prometheus``
   * - ``opensearch``
     - ``charts/opensearch``
     - ``opensearch``
   * - ``opensearch-dashboard``
     - ``charts/opensearch-dashboards``
     - ``opensearch``
   * - ``fluent-bit``
     - ``charts/fluent-bit``
     - ``fluentbit``
   * - ``jaeger``
     - ``charts/jaeger``
     - ``jaeger``
   * - ``falco``
     - ``charts/falco``
     - ``falco``
   * - ``kyverno``
     - ``charts/kyverno``
     - ``kyverno``
   * - ``trivy-operator``
     - ``charts/trivy-operator``
     - ``trivy-system``
   * - ``kueue``
     - ``charts/kueue``
     - ``kueue-system``
   * - ``argo-workflows``
     - ``charts/argo-workflows``
     - ``argo-workflows``
   * - ``kubeflow-trainer``
     - ``charts/kubeflow-trainer``
     - ``kubeflow-system``
   * - ``gen3``
     - ``charts/gen3-2025.08``
     - ``gen3``

The repository also contains chart defaults and dependencies. Only paths
referenced by an Argo CD Application are part of the active GitOps graph.

``kueue``
---------

Application ``kueue-config`` recursively applies ``kueue`` to
``kueue-system``. It manages CPU and GPU ClusterQueues and node-label-related
configuration after the Kueue controller chart is installed.

``postgres``
------------

Application ``gen3-db`` recursively applies ``postgres``. The directory
contains:

* The CloudNativePG ``gen3-db-cluster`` definition.
* The GEN3 database permissions Job.
* Database Secrets for the cluster and GEN3 namespace.

Automated pruning and self-healing are enabled. This makes duplicate Secret
definitions and plaintext credentials especially risky; resolve them before a
clean rebuild.

``storage``
-----------

Storage has two Argo CD ownership levels:

* ``rook-ceph-cluster`` reads ``storage/rook-ceph/cluster`` and manages the
  ``CephCluster`` resource.
* ``rook-ceph-storage`` recursively reads ``storage/rook-ceph/storage`` and
  manages pools, filesystems, StorageClasses, object storage, users, and bucket
  claims.

Both Applications have automated pruning and self-healing disabled because
storage changes can be destructive and require deliberate review.

``tools``
---------

Application ``rook-ceph-tools`` recursively applies ``tools/rook-ceph``. It
manages the Ceph toolbox Deployment. The ``platform-ingresses`` Application
exposes the dashboard through Rook's existing ClusterIP Service, so no
additional NodePort Service is managed here.

External chart exception
------------------------

The cert-manager Application does not use the local ``charts`` directory. It
pulls its Helm chart directly from ``https://charts.jetstack.io``. The
``infrastructure`` AppProject explicitly permits that source repository.

Ownership check
---------------

Use the source path shown by each live Application to confirm ownership::

   kubectl -n argocd get applications \
     -o custom-columns=NAME:.metadata.name,PATH:.spec.source.path,NAMESPACE:.spec.destination.namespace

Before modifying a resource manually, determine whether Argo CD manages it and
whether self-healing or pruning is enabled.
