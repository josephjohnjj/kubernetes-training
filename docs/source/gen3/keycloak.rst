GEN3 Keycloak Installation and Configuration
=============================================

Keycloak is the OpenID Connect identity provider used by Fence. The current
GEN3 values expect realm ``genome`` and client ``gen3-fence``.

Keycloak clients in this environment
------------------------------------

.. list-table::
   :header-rows: 1
   :widths: 18 23 18 14 27

   * - Client
     - Purpose
     - Client authentication
     - PKCE
     - Callback
   * - ``gen3-fence``
     - GEN3 user login
     - On (confidential)
     - ``plain``
     - GEN3 ``/user/login/generic_oidc_idp/login``
   * - ``argocd``
     - Argo CD user login
     - Off (public)
     - ``S256``
     - Argo CD ``/auth/callback`` and ``/pkce/verify``

Both clients use realm ``genome`` but are otherwise independent. See
:doc:`../argocd/keycloak_oidc` for the Argo CD client and groups mapper.

Transport summary
-----------------

.. list-table::
   :header-rows: 1
   :widths: 35 20 45

   * - Traffic
     - Protocol
     - Reason
   * - Browser to GEN3
     - HTTPS
     - Revproxy redirects HTTP and uses secure cookies.
   * - Browser to Argo CD
     - HTTPS
     - Public administrative endpoint.
   * - Fence/Argo CD discovery to Keycloak
     - HTTP (POC only)
     - Avoids the untrusted Keycloak certificate.
   * - Internal Kubernetes services
     - Mostly HTTP
     - Cluster-local POC configuration.

Production must give Keycloak a trusted certificate and migrate its advertised
issuer and every discovery consumer to HTTPS together.

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

The tested installation uses Bitnami chart ``25.2.0``, Keycloak ``26.3.3``,
and image ``bitnamilegacy/keycloak:26.3.3-debian-12-r0``. The repository
disables the bundled PostgreSQL database. Adapt the values to reference
``keycloak-db`` using the chart's password Secret option, then render and
review before installation::

   export KEYCLOAK_CHART_VERSION='25.2.0'
   helm template keycloak bitnami/keycloak \
     --version "${KEYCLOAK_CHART_VERSION}" -n keycloak -f values.yaml
   helm upgrade --install keycloak bitnami/keycloak \
     --version "${KEYCLOAK_CHART_VERSION}" \
     --namespace keycloak --create-namespace --values values.yaml

Record Helm history before and after an upgrade. Roll back to the previous
revision if the new pod does not become ready::

   helm history keycloak -n keycloak
   helm rollback keycloak PREVIOUS_REVISION -n keycloak
   kubectl -n keycloak rollout status statefulset/keycloak --timeout=5m

.. warning::

   Repository files disagree about ``postgresql.enabled`` and currently contain
   a literal database password. For this deployment the external database is
   intended, so use ``postgresql.enabled: false`` and migrate the password to a
   Secret before following this procedure.

Expose Keycloak
---------------

Keep the Keycloak Service as ``ClusterIP`` and route it through the NGINX
Ingress in ``manifests/ingress/05-keycloak-ingress.yaml``::

   kubectl apply -f manifests/ingress/05-keycloak-ingress.yaml
   kubectl -n keycloak get ingress keycloak

The repository hostname is ``keycloak.44.203.188.20.nip.io``. Replace it in the
Ingress and GEN3 values if the external address changes.

Configure the realm
-------------------

In the Keycloak administration console:

#. Create realm ``genome``.
#. Create an OpenID Connect client with client ID ``gen3-fence``.
#. Enable client authentication and copy the generated client secret for the
   Fence configuration.
#. Enable Standard flow (the OAuth 2.0 authorization-code flow).
#. Disable Authorization and Implicit flow. Direct access grants are optional
   and are not required for browser login.
#. Set PKCE Method to ``plain`` for the tested ``2025.08`` Fence client.
#. Configure the access settings exactly as follows::

      Root URL:
      https://gen3.44.203.188.20.nip.io

      Home URL:
      https://gen3.44.203.188.20.nip.io

      Valid redirect URIs:
      https://gen3.44.203.188.20.nip.io/user/login/generic_oidc_idp/login

      Web origins:
      https://gen3.44.203.188.20.nip.io

      Admin URL:
      <leave empty>

#. Remove obsolete callback entries that use HTTP or omit the ``/user``
   prefix.
#. Copy the generated client secret into the Secret consumed by Fence.
#. Create or federate users and ensure their email claim is populated.

The valid redirect URI is an exact value, not merely a documentation example.
The ``/user`` prefix is required because Revproxy routes external ``/user/*``
requests to Fence and strips that prefix before proxying. Without it, the OIDC
response is routed to Portal, which displays its generic not-found page.

Protocol split for this POC
---------------------------

This deployment intentionally uses different protocols for the two OIDC
traffic paths:

* Fence performs server-side discovery over HTTP at
  ``http://keycloak.44.203.188.20.nip.io/realms/genome/.well-known/openid-configuration``.
  This avoids certificate verification failures caused by the POC's
  self-signed Keycloak certificate.
* The browser returns from Keycloak over HTTPS to
  ``https://gen3.44.203.188.20.nip.io/user/login/generic_oidc_idp/login``.
  Revproxy redirects the public HTTP GEN3 URL to HTTPS and uses secure session
  cookies, so the registered callback must use HTTPS.

This split is a POC workaround. A production deployment should install a
trusted certificate for Keycloak and then use HTTPS for discovery as well.

Configure Fence
---------------

The relevant values are under ``fence.FENCE_CONFIG.OPENID_CONNECT`` in
``charts/gen3-2025.08/values/gen3-values.yaml``. They define:

* Discovery URL:
  ``http://keycloak.44.203.188.20.nip.io/realms/genome/.well-known/openid-configuration``
* Redirect URL:
  ``https://gen3.44.203.188.20.nip.io/user/login/generic_oidc_idp/login``
* Client ID: ``gen3-fence``
* User identifier claim: ``email``
* Scope: ``openid email``

The Keycloak client secret and the Fence ``client_secret`` must be identical.
Move the secret out of the values file before a production deployment.

Verify authentication
---------------------

Verify discovery first::

   curl -fsS \
     http://keycloak.44.203.188.20.nip.io/realms/genome/.well-known/openid-configuration

Then open GEN3, select ``Keycloak Login``, authenticate, and confirm the browser
returns to the GEN3 callback without redirect or issuer errors. Check Fence logs
without printing tokens::

   kubectl -n gen3 logs deployment/fence-deployment --tail=200

Confirm the deployed callback and Revproxy route::

   POD=$(kubectl -n gen3 get pods -l app=fence \
     --sort-by=.metadata.creationTimestamp \
     -o jsonpath='{.items[-1:].metadata.name}')
   kubectl -n gen3 exec "$POD" -c fence -- \
     sed -n '/generic_oidc_idp:/,/google:/p' \
     /var/www/fence/fence-config.yaml

   REVPROXY_POD=$(kubectl -n gen3 get pods -l app=revproxy \
     -o jsonpath='{.items[0].metadata.name}')
   kubectl -n gen3 logs "$REVPROXY_POD" --since=5m | \
     grep generic_oidc_idp

The callback request must begin with ``/user/login/`` and the Revproxy log must
identify Fence, rather than Portal, as the upstream service.
