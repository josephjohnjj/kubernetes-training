GEN3 Getting Started
====================

This is the canonical fresh-install path for the GEN3 2025.08 proof of
concept. Follow the linked pages for component detail, but keep this order: it
reflects the dependencies between namespaces, storage, databases, identity,
and GEN3 initialization Jobs.

.. warning::

   The repository contains environment-specific hostnames and plaintext POC
   credentials. Fork the repository, replace those values, and rotate every
   credential before exposing the deployment or loading non-public data.

1. Clone and select the cluster
-------------------------------

Install ``git``, ``kubectl``, Helm 3, and optionally the ``argocd`` and
``kubectl cnpg`` CLIs. Clone the operator's fork and verify the target context::

   git clone https://github.com/REPLACE_WITH_OWNER/kubernetes-training.git
   cd kubernetes-training
   kubectl config current-context
   kubectl cluster-info
   kubectl get nodes -o wide

Review :doc:`prerequisites` before continuing. The Ceph manifests assume nodes
``storage1`` through ``storage3`` and claim specified raw devices; applying
them to the wrong machines can destroy data.

2. Customize the environment
----------------------------

Replace the repository-specific values before the first Argo CD sync:

* GEN3, Keycloak, and Argo CD public hostnames.
* ingress-nginx external address or load-balancer routing.
* PostgreSQL, Elasticsearch, Keycloak, and OIDC credentials.
* Ceph storage nodes, device names, and requested capacity.
* Keycloak realm/client settings and exact callback URLs.
* GEN3 dictionary URL, Elasticsearch indices, and resource requests.
* UserSync source: embedded ``USER_YAML`` or an S3 ``users.yaml`` object.

The primary GEN3 overlay is
``charts/gen3-2025.08/values/gen3-values.yaml``. Its ``DEPLOYMENT CHECKLIST``
marks values that must be reviewed. Also inspect:

* ``manifests/keycloak/values.yaml``
* ``manifests/ingress/keycloak-ingress.yaml``
* ``postgres/secrets``
* ``storage/rook-ceph/cluster/01-rook-ceph-cluster.yaml``
* ``charts/eck-stack``

Use :doc:`secrets` to identify object names and ownership. Do not commit newly
generated plaintext credentials.

3. Validate before pushing
---------------------------

Render the exact values stack used by the GEN3 Argo CD Application::

   helm lint charts/gen3-2025.08 \
     -f charts/gen3-2025.08/values/gen3-values.yaml \
     -f charts/gen3-2025.08/values.d/00-etl-mapping.yaml \
     -f charts/gen3-2025.08/values.d/01-usersync.yaml \
     -f charts/gen3-2025.08/values.d/02-portal-gitops-css.yaml \
     -f charts/gen3-2025.08/values.d/03-portal-gitops-json.yaml

   helm template gen3 charts/gen3-2025.08 --namespace gen3 \
     -f charts/gen3-2025.08/values/gen3-values.yaml \
     -f charts/gen3-2025.08/values.d/00-etl-mapping.yaml \
     -f charts/gen3-2025.08/values.d/01-usersync.yaml \
     -f charts/gen3-2025.08/values.d/02-portal-gitops-css.yaml \
     -f charts/gen3-2025.08/values.d/03-portal-gitops-json.yaml \
     > /tmp/gen3-rendered.yaml

Commit and push reviewed changes to the revision tracked by the Argo CD
Applications.

4. Install and bootstrap Argo CD
--------------------------------

Follow :doc:`argocd_bootstrap`. In summary, install a pinned Argo CD release,
then apply the project and root Applications::

   kubectl apply -f argocd/bootstrap/01-project-infrastructure.yaml
   kubectl apply -f argocd/bootstrap/02-argocd-rbac-cm.yaml
   kubectl apply -f argocd/bootstrap/03-infrastructure.yaml

The infrastructure root creates namespace ``gen3`` at sync wave ``-1``. This
must happen before the storage child Application creates ObjectBucketClaims in
that namespace.

5. Reconcile infrastructure in dependency order
------------------------------------------------

Do not enable everything at once on an untested cluster. Use the gates in
:doc:`readiness` after each group:

#. Rook-Ceph operator, CSI drivers, cluster, and toolbox.
#. Ceph pools, filesystems, StorageClasses, object store, and bucket claims.
#. CloudNativePG and ECK operators.
#. GEN3 PostgreSQL and Elasticsearch resources.
#. ingress-nginx.
#. Keycloak database, Keycloak, and its Ingress.

``Synced`` does not mean a database has quorum or an object bucket is bound.
Verify health before deploying a dependent component.

6. Configure Keycloak
---------------------

The tested Keycloak installation uses Bitnami chart ``25.2.0`` with Keycloak
``26.3.3``. Follow :doc:`keycloak` for the confidential ``gen3-fence`` client.
Follow :doc:`../argocd/keycloak_oidc` for the separate public ``argocd`` PKCE
client. Never reuse one client's redirect URI or secret for the other.

7. Deploy GEN3
--------------

Once storage, PostgreSQL, Elasticsearch, ingress-nginx, and Keycloak are ready,
create the workload root Application::

   kubectl apply -f argocd/bootstrap/04-applications.yaml
   kubectl -n argocd get application gen3 --watch

Inspect the operation rather than starting a second sync while one is running::

   kubectl -n argocd get application gen3 \
     -o jsonpath='revision={.status.sync.revision}{"\n"}sync={.status.sync.status}{"\n"}health={.status.health.status}{"\n"}operation={.status.operationState.phase}{"\n"}message={.status.operationState.message}{"\n"}'

If automation is disabled and no operation is active, run
``argocd app sync gen3``. Database creation and migration Jobs must complete
before the corresponding Deployments become ready.

8. Run smoke tests
------------------

Use :doc:`readiness` for the full checks. At minimum::

   kubectl -n gen3 wait --for=condition=Available deployment --all --timeout=10m
   kubectl -n gen3 get jobs,pods,ingress
   curl -ksS -o /dev/null -w '%{http_code}\n' \
     https://REPLACE_WITH_GEN3_HOST/_status

Test these browser paths through Revproxy:

* ``/``
* ``/DD``
* ``/explorer``
* ``/identity``
* ``/login`` followed by a complete Keycloak login

Create a manual UserSync run from the CronJob and wait for completion::

   JOB="usersync-manual-$(date +%s)"
   kubectl -n gen3 create job --from=cronjob/usersync "$JOB"
   kubectl -n gen3 wait --for=condition=Complete "job/$JOB" --timeout=5m
   kubectl -n gen3 logs "job/$JOB" --all-containers --tail=200

9. Understand reset boundaries
------------------------------

A stateless GEN3 reset deletes and recreates only the ``gen3`` Application and
workloads while retaining CloudNativePG PVCs and Ceph bucket data. Reusing a
database requires every new image to contain the database's current migration
revision.

A full reset also removes GEN3 databases/PVCs and retained object buckets. It
is destructive and must not be performed without a verified backup, an exact
resource inventory, and explicit approval. ``cnpg-sc`` uses reclaim policy
``Delete`` while ``gen3-bucket`` uses ``Retain``; namespace deletion alone does
not guarantee identical cleanup behavior.

Do not delete Deployments, Applications, namespaces, PVCs, or bucket
finalizers as routine sync troubleshooting. First inspect Argo CD health, pod
events, init-container logs, and ownership.

10. Build this documentation
----------------------------

Create an isolated environment and install the pinned documentation tools::

   python3 -m venv .venv-docs
   source .venv-docs/bin/activate
   pip install -r docs/requirements.txt
   sphinx-build -W --keep-going -b html docs/source docs/build/html

Fix warnings introduced by changed pages before merging. The repository may
contain older warnings in unrelated tutorial pages; record and address those
separately rather than hiding new warnings.
