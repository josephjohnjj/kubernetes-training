GEN3 Keycloak Installation and Configuration
=============================================

Keycloak is the OpenID Connect identity provider used by Fence. The current
GEN3 values expect realm ``genome`` and client ``gen3-fence``.

Prepare the database
--------------------

The Keycloak values use the separate CloudNativePG service
``cnpg-cluster-rw.cnpg-database.svc.cluster.local:5432`` and database
``keycloak``. Confirm that this cluster exists and create the database and role
through an approved administrative session. Supply the password through a
Kubernetes Secret; do not keep it in ``values.yaml``.

Install Keycloak
----------------

Create the namespace and a values file containing no literal password::

   kubectl create namespace keycloak --dry-run=client -o yaml | kubectl apply -f -
   kubectl -n keycloak create secret generic keycloak-db \
     --from-literal=db-password='<generate-a-strong-password>'

The repository pins image ``bitnamilegacy/keycloak:26.3.3-debian-12-r0`` and
disables the bundled PostgreSQL database. It does not currently record the
Bitnami chart version. Select and record a tested chart version, adapt its
values to reference ``keycloak-db`` using that version's password Secret
option, then render and review before installation::

   export KEYCLOAK_CHART_VERSION='<tested-chart-version>'
   helm template keycloak bitnami/keycloak \
     --version "${KEYCLOAK_CHART_VERSION}" -n keycloak -f values.yaml
   helm upgrade --install keycloak bitnami/keycloak \
     --version "${KEYCLOAK_CHART_VERSION}" \
     --namespace keycloak --create-namespace --values values.yaml

.. warning::

   Repository files disagree about ``postgresql.enabled`` and currently contain
   a literal database password. For this deployment the external database is
   intended, so use ``postgresql.enabled: false`` and migrate the password to a
   Secret before following this procedure.

Expose Keycloak
---------------

Keep the Keycloak Service as ``ClusterIP`` and route it through the NGINX
Ingress in ``manifests/ingress/keycloak-ingress.yaml``::

   kubectl apply -f manifests/ingress/keycloak-ingress.yaml
   kubectl -n keycloak get ingress keycloak

The repository hostname is ``keycloak.44.203.188.20.nip.io``. Replace it in the
Ingress and GEN3 values if the external address changes.

Configure the realm
-------------------

In the Keycloak administration console:

#. Create realm ``genome``.
#. Create an OpenID Connect client with client ID ``gen3-fence``.
#. Enable the authorization-code flow (standard flow).
#. Set the valid redirect URI to
   ``http://gen3.44.203.188.20.nip.io/login/generic_oidc_idp/login``.
#. Set allowed web origins to the GEN3 origin.
#. Copy the generated client secret into the Secret consumed by Fence.
#. Create or federate users and ensure their email claim is populated.

For HTTPS, use ``https`` consistently in the Keycloak hostname, Fence discovery
URL, redirect URI, web origins, and Ingress TLS configuration.

Configure Fence
---------------

The relevant values are under ``fence.FENCE_CONFIG.OPENID_CONNECT`` in
``charts/gen3-2025.08/values/gen3-values.yaml``. They define:

* Discovery URL:
  ``/realms/genome/.well-known/openid-configuration``
* Client ID: ``gen3-fence``
* User identifier claim: ``email``
* Scope: ``openid email``

Move the client secret out of the values file before deployment.

Verify authentication
---------------------

Verify discovery first::

   curl -fsS \
     http://keycloak.44.203.188.20.nip.io/realms/genome/.well-known/openid-configuration

Then open GEN3, select ``Keycloak Login``, authenticate, and confirm the browser
returns to the GEN3 callback without redirect or issuer errors. Check Fence logs
without printing tokens::

   kubectl -n gen3 logs deployment/fence-deployment --tail=200
