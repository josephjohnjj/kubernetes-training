Argo CD Bootstrap for GEN3
==========================

The repository uses an app-of-apps layout. ``infrastructure.yaml`` discovers
platform Applications and ``applications.yaml`` discovers workloads including
GEN3.

Install Argo CD
---------------

Pin the Argo CD install manifest to an approved release for reproducibility.
The existing helper uses the mutable ``stable`` branch; the placeholder below
must be replaced with the selected version::

   export ARGOCD_VERSION='<approved-version>'
   kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
   kubectl apply -n argocd --server-side --force-conflicts \
     -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"
   kubectl -n argocd wait --for=condition=Available deployment --all --timeout=5m

Apply the project first
-----------------------

The root Applications reference the ``infrastructure`` AppProject, so apply it
before them::

   kubectl apply -f argocd/bootstrap/01-project-infrastructure.yaml
   kubectl apply -f argocd/bootstrap/02-argocd-rbac-cm.yaml

The AppProject permits namespace ``gen3``. The infrastructure root also creates
that namespace at sync wave ``-1`` so it exists before the storage child
Application reconciles GEN3 ObjectBucketClaims.

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
