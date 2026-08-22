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
     - HTTPS
     - Keycloak uses a trusted ingress certificate and advertises HTTPS URLs.
   * - Internal Kubernetes services
     - Mostly HTTP
     - Cluster-local POC configuration.

Keycloak trusts ingress-nginx's forwarded scheme through
``proxyHeaders: xforwarded``. Its public issuer, discovery endpoints, and
client redirect URIs therefore remain consistently HTTPS.

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

The tested installation uses the vendored Bitnami chart ``25.2.0``, Keycloak
``26.3.3``, and image
``bitnamilegacy/keycloak:26.3.3-debian-12-r0``. The repository disables the
bundled PostgreSQL database. Argo CD renders
``charts/keycloak/keycloak-values.yaml`` and deploys the chart through the
``keycloak`` child Application.

The values expect existing Secrets named ``keycloak`` and
``keycloak-externaldb``. Do not commit either password. Render changes before
committing them::

   helm lint charts/keycloak -f charts/keycloak/keycloak-values.yaml
   helm template keycloak charts/keycloak \
     --namespace keycloak \
     -f charts/keycloak/keycloak-values.yaml

After Argo synchronization, verify the StatefulSet rollout::

   kubectl -n argocd get application keycloak
   kubectl -n keycloak rollout status statefulset/keycloak --timeout=5m

Do not run direct ``helm upgrade`` commands after Argo CD adopts the release.

Expose Keycloak
---------------

Keep the Keycloak Service as ``ClusterIP`` and route it through the
Argo-managed NGINX Ingress in ``argocd/ingresses/05-keycloak-ingress.yaml``::

   kubectl -n argocd get application platform-ingresses
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

HTTPS OIDC transport
--------------------

Fence performs server-side discovery through Keycloak's trusted HTTPS ingress
at
``https://keycloak.44.203.188.20.nip.io/realms/genome/.well-known/openid-configuration``.
The browser also returns over HTTPS to
``https://gen3.44.203.188.20.nip.io/user/login/generic_oidc_idp/login``.
The issuer returned by discovery, the configured discovery URL, and each
registered callback must use the same public HTTPS origins.

Configure Fence
---------------

The relevant values are under ``fence.FENCE_CONFIG.OPENID_CONNECT`` in
``charts/gen3-2025.08/values/gen3-values.yaml``. They define:

* Discovery URL:
  ``https://keycloak.44.203.188.20.nip.io/realms/genome/.well-known/openid-configuration``
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
     https://keycloak.44.203.188.20.nip.io/realms/genome/.well-known/openid-configuration

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
