Argo CD Bootstrap for GEN3
==========================

The repository uses an app-of-apps layout. ``infrastructure.yaml`` discovers
platform Applications and ``applications.yaml`` discovers workloads including
GEN3.

Install Argo CD
---------------

Install Argo CD with the pinned upstream Helm chart.  Helm owns the Argo CD
deployments, CRDs, cluster roles, Services, and RBAC ConfigMap; Argo CD then
owns the platform and workload resources below ``argocd/``::

   helm repo add argo https://argoproj.github.io/argo-helm
   helm repo update argo
   helm upgrade --install argocd argo/argo-cd \
     --version 10.3.3 \
     --namespace argocd \
     --create-namespace \
     --values charts/argocd/values.yaml \
     --wait \
     --timeout 10m

Chart ``10.3.3`` installs Argo CD ``v3.5.1``.  Review and deliberately update
both versions when upgrading.  The chart keeps the server as a ``ClusterIP``;
the repository-managed ingress-nginx route later connects to its HTTPS port.

Verify the Helm release and deployments::

   helm status argocd --namespace argocd
   kubectl -n argocd wait --for=condition=Available deployment --all --timeout=5m

Apply the project first
-----------------------

The root Applications reference the ``infrastructure`` AppProject, so apply it
before them::

   kubectl apply -f argocd/bootstrap/01-project-infrastructure.yaml

Do not apply ``argocd/bootstrap/02-argocd-rbac-cm.yaml`` in the Helm-managed
installation.  The equivalent policy is declared in
``charts/argocd/values.yaml``, making Helm the sole owner of
``argocd-rbac-cm``.

The AppProject permits namespace ``gen3``. The infrastructure root also creates
that namespace at sync wave ``-1`` so it exists before the storage child
Application reconciles GEN3 ObjectBucketClaims.

The project also permits ``keycloak`` for the Git-managed Keycloak ingress.
On an existing cluster, reapply the project file after pulling this change so
the ``platform-ingresses`` Application can reconcile that namespace::

   kubectl apply -f argocd/bootstrap/01-project-infrastructure.yaml

Bootstrap platform applications
-------------------------------

Apply infrastructure first and wait for storage and operators to become ready::

   kubectl apply -f argocd/bootstrap/03-infrastructure.yaml
   kubectl -n argocd get applications --watch

Use :doc:`readiness` to validate Ceph, CloudNativePG, ECK, and ingress-nginx.
Do not use ``Synced`` as the only readiness signal.

Bootstrap GEN3 applications
---------------------------

After prerequisites and Secrets are ready::

   kubectl apply -f argocd/bootstrap/04-applications.yaml
   kubectl -n argocd get application gen3
   kubectl -n argocd wait --for=jsonpath='{.status.sync.status}'=Synced \
     application/gen3 --timeout=10m

The GEN3 Application deploys ``charts/gen3-2025.08`` with its base environment
values plus ETL, UserSync, portal CSS, and portal JSON overlays.

Safe troubleshooting
--------------------

Inspect conditions and resource health before forcing a sync::

   kubectl -n argocd describe application gen3
   argocd app get gen3
   argocd app diff gen3

Avoid deleting Applications, PVCs, Ceph resources, or namespaces to repair a
sync. Argo CD pruning is enabled for GEN3 and the database Application, so
review every Git deletion carefully.
