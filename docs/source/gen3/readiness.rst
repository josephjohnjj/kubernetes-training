GEN3 Deployment Readiness Gates
===============================

Do not continue merely because an Argo CD Application is ``Synced``. A stage is
ready only when its controllers and workloads report healthy runtime state.

Stage 1: Kubernetes
-------------------

Pass criteria:

* All intended nodes are ``Ready``.
* CoreDNS is available.
* Nodes can pull an image and pods can resolve service DNS.

Commands::

   kubectl get nodes
   kubectl -n kube-system get deployment coredns
   kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded

Stage 2: Argo CD
----------------

Pass criteria: all Argo CD pods are ready, the ``infrastructure`` AppProject
exists, and root Applications are accepted::

   kubectl -n argocd wait --for=condition=Available deployment --all --timeout=5m
   kubectl -n argocd get appproject infrastructure
   kubectl -n argocd get applications

Stage 3: Ceph and CSI
---------------------

Pass criteria: ``CephCluster/rook-ceph`` is ``Ready`` with healthy Ceph status,
all nine OSDs are up and in, and CSI controller/node pods are ready::

   kubectl -n rook-ceph get cephcluster rook-ceph
   kubectl -n rook-ceph get pods
   kubectl -n rook-ceph exec deploy/rook-ceph-tools -- ceph status
   kubectl -n rook-ceph exec deploy/rook-ceph-tools -- ceph osd status

Stage 4: Storage resources
--------------------------

Pass criteria: the required pools and object store are ready, StorageClasses
exist, and both GEN3 ObjectBucketClaims are ``Bound``::

   kubectl -n rook-ceph get cephblockpool cnpg-pool gen3-elasticsearch-pool
   kubectl -n rook-ceph get cephobjectstore gen3-store
   kubectl get storageclass cnpg-sc gen3-elasticsearch-sc gen3-bucket
   kubectl -n gen3 get objectbucketclaim users-bucket schema-bucket

Stage 5: Database and search operators
--------------------------------------

Pass criteria: CloudNativePG and ECK controllers are available and their CRDs
exist::

   kubectl -n cnpg-system wait --for=condition=Available deployment --all --timeout=5m
   kubectl -n elasticsearch get deployments
   kubectl get crd clusters.postgresql.cnpg.io elasticsearches.elasticsearch.k8s.elastic.co

Stage 6: PostgreSQL and Elasticsearch
-------------------------------------

Pass criteria: CloudNativePG reports three ready instances, three database PVCs
are ``Bound``, Elasticsearch is green or yellow as designed, and its ``100Gi``
PVC is ``Bound``::

   kubectl -n gen3-db get cluster,pod,pvc
   kubectl cnpg status gen3-db-cluster -n gen3-db
   kubectl -n elasticsearch get elasticsearch,pod,pvc

Stage 7: ingress-nginx and Keycloak
-----------------------------------

Pass criteria: the ingress controller is ready, Keycloak and its database are
ready, the realm discovery endpoint responds, and the GEN3 OIDC client has the
correct redirect URI::

   kubectl -n ingress-nginx get deployment,service
   kubectl -n keycloak get pod,service,ingress
   curl -fsS https://keycloak.44.203.188.20.nip.io/realms/genome/.well-known/openid-configuration

Replace the example hostname before running the request.

Stage 8: GEN3
-------------

Pass criteria: Argo CD reports ``Synced`` and ``Healthy``, all expected
Deployments are available, initialization Jobs succeed, and no pod is in a
restart loop::

   kubectl -n argocd get application gen3
   kubectl -n gen3 get deployments
   kubectl -n gen3 get jobs
   kubectl -n gen3 get pods
   kubectl -n gen3 wait --for=condition=Available deployment --all --timeout=10m

Stage 9: Functional checks
--------------------------

Pass criteria:

* GEN3 home page loads through ingress-nginx.
* Keycloak login returns to GEN3 successfully.
* Fence UserSync completes using its configured source. The active POC uses
  embedded ``USER_YAML``; an S3-enabled deployment must read ``users.yaml``
  from Ceph RGW with the current OBC credentials.
* Sheepdog can submit and retrieve a test record.
* Tube completes and creates the expected Elasticsearch indices.
* Guppy and Portal return the indexed test data.

Keep the Application at the failing stage and investigate before allowing
dependent stages to sync.

Run an explicit UserSync smoke test::

   JOB="usersync-manual-$(date +%s)"
   kubectl -n gen3 create job --from=cronjob/usersync "$JOB"
   kubectl -n gen3 wait --for=condition=Complete "job/$JOB" --timeout=5m
   kubectl -n gen3 logs "job/$JOB" --all-containers --tail=200
