GEN3 Secret Templates
=====================

These templates document required object names and keys without embedding real
credentials. Prefer External Secrets, Sealed Secrets, or another encrypted
GitOps mechanism. Plain Kubernetes Secret manifests with ``stringData`` are not
encrypted and must not be committed after substitution.

Generate values
---------------

Generate each password independently with an approved password manager. Never
reuse the example values already present in the repository.

Secret ownership and ordering
-----------------------------

.. list-table::
   :header-rows: 1
   :widths: 24 16 27 33

   * - Object
     - Namespace
     - Owner
     - Required before
   * - ``gen3db-secret``
     - ``gen3-db``
     - Database infrastructure
     - CloudNativePG bootstrap
   * - ``superuser-secret``
     - ``gen3-db``
     - Database infrastructure
     - CloudNativePG bootstrap
   * - ``postgres-dbcreds``
     - ``gen3``
     - Database infrastructure
     - GEN3 database-creation Jobs
   * - ``users-bucket``
     - ``gen3``
     - Rook OBC provisioner
     - Fence pods that reference S3 credentials
   * - ``keycloak-db``
     - ``keycloak``
     - Keycloak operator/install process
     - Keycloak startup
   * - Fence OIDC client credential
     - ``gen3``
     - Secret manager/operator
     - Fence OIDC login

Do not declare the same object from two Argo CD Applications. In particular,
the OBC provisioner owns ``users-bucket`` and the GEN3 chart owns its
service-specific database Secrets.

CloudNativePG bootstrap owner
-----------------------------

Create ``gen3db-secret`` in ``gen3-db`` because the CloudNativePG Cluster
references this exact name::

   apiVersion: v1
   kind: Secret
   metadata:
     name: gen3db-secret
     namespace: gen3-db
   type: kubernetes.io/basic-auth
   stringData:
     username: gen3db
     password: REPLACE_WITH_GENERATED_PASSWORD

CloudNativePG superuser
-----------------------

::

   apiVersion: v1
   kind: Secret
   metadata:
     name: superuser-secret
     namespace: gen3-db
   type: kubernetes.io/basic-auth
   stringData:
     username: postgres
     password: REPLACE_WITH_GENERATED_PASSWORD

GEN3 database-creation credentials
----------------------------------

The GEN3 chart expects ``postgres-dbcreds`` in ``gen3``. Confirm the precise
keys required by the rendered chart before applying this template::

   apiVersion: v1
   kind: Secret
   metadata:
     name: postgres-dbcreds
     namespace: gen3
   type: Opaque
   stringData:
     username: postgres
     password: REPLACE_WITH_SUPERUSER_PASSWORD
     host: gen3-db-cluster-rw.gen3-db.svc.cluster.local
     port: "5432"
     database: postgres

Keep exactly one desired definition of this Secret. The repository stores it in
``postgres/secrets/03-postgres-dbcreds.yaml``. Service-specific database Secrets,
including ``indexd-dbcreds`` and ``sheepdog-dbcreds``, are owned by the GEN3
Helm chart and must not also be declared under ``postgres/secrets``.

Ceph S3 bucket credentials
--------------------------

Rook normally creates the ``users-bucket`` Secret when its ObjectBucketClaim is
bound. Fence expects these keys::

   apiVersion: v1
   kind: Secret
   metadata:
     name: users-bucket
     namespace: gen3
   type: Opaque
   stringData:
     AWS_ACCESS_KEY_ID: REPLACE_WITH_RADOSGW_ACCESS_KEY
     AWS_SECRET_ACCESS_KEY: REPLACE_WITH_RADOSGW_SECRET_KEY

Do not create a competing Secret if the OBC provisioner already owns it.

Fence OIDC client secret
------------------------

Store the Keycloak client secret separately and wire it into the chart using an
existing Secret or external-secret option::

   apiVersion: v1
   kind: Secret
   metadata:
     name: fence-keycloak-oidc
     namespace: gen3
   type: Opaque
   stringData:
     client-secret: REPLACE_WITH_KEYCLOAK_CLIENT_SECRET

.. note::

   This manifest documents the desired production ownership model. The current
   POC still places the Fence ``client_secret`` directly in
   ``charts/gen3-2025.08/values/gen3-values.yaml`` because the vendored chart
   has not yet been wired to consume ``fence-keycloak-oidc``. Do not create the
   Secret and assume it is active; verify the rendered Deployment/Secret first.

Keycloak database Secret
------------------------

::

   apiVersion: v1
   kind: Secret
   metadata:
     name: keycloak-db
     namespace: keycloak
   type: Opaque
   stringData:
     db-password: REPLACE_WITH_GENERATED_PASSWORD

Safe creation from a terminal
-----------------------------

Avoid placing passwords directly in shell history. Create a protected temporary
file, use ``kubectl create secret --from-file`` where the chart supports it, or
use the organization's secret-management CLI. Verify only metadata and key
names::

   kubectl -n gen3-db get secret gen3db-secret superuser-secret
   kubectl -n gen3 get secret postgres-dbcreds users-bucket
   kubectl -n gen3 get secret postgres-dbcreds \
     -o jsonpath='{range $k,$v := .data}{$k}{"\n"}{end}'

Never include ``-o yaml`` output for Secrets in tickets or documentation.
