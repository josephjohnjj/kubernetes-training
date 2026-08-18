Keycloak OIDC Integration for Argo CD
======================================

Argo CD uses Keycloak for browser authentication through OpenID Connect
(OIDC). This is separate from the ``gen3-fence`` client: Argo CD has its own
client, redirect URIs, and PKCE settings.

Current environment
-------------------

.. list-table::
   :header-rows: 1
   :widths: 35 65

   * - Setting
     - Value
   * - Keycloak realm
     - ``genome``
   * - Keycloak client ID
     - ``argocd``
   * - Argo CD URL
     - ``https://argocd.44.203.188.20.nip.io``
   * - Keycloak issuer
     - ``http://keycloak.44.203.188.20.nip.io/realms/genome``
   * - Client type
     - Public OIDC client using authorization code and PKCE
   * - PKCE method
     - ``S256``

Replace both ``nip.io`` hostnames when deploying into another environment.

Configure the Keycloak client
-----------------------------

In the Keycloak administration console, select realm ``genome`` and create an
OpenID Connect client with Client ID ``argocd``. Configure its capability
settings as follows::

   Client authentication: Off
   Authorization: Off
   Standard flow: On
   Implicit flow: Off
   Service accounts roles: Off
   PKCE Method: S256

This is a public client. Argo CD uses PKCE, so this configuration does not use a
Keycloak client secret.

Configure the access settings exactly as follows::

   Root URL:
   https://argocd.44.203.188.20.nip.io

   Home URL:
   https://argocd.44.203.188.20.nip.io

   Valid redirect URIs:
   https://argocd.44.203.188.20.nip.io/auth/callback
   https://argocd.44.203.188.20.nip.io/pkce/verify

   Web origins:
   https://argocd.44.203.188.20.nip.io

   Admin URL:
   <leave empty>

The redirect URIs must match the external Argo CD URL exactly, including the
``https`` scheme. Do not reuse the Fence callback or the ``gen3-fence`` client.

Configure the groups protocol mapper
------------------------------------

Keycloak does not include group membership in the ID token by default. Add a
Group Membership protocol mapper to the dedicated scope for the ``argocd``
client:

#. Open the ``argocd`` client and select the **Client scopes** tab.
#. Select ``argocd-dedicated``, the dedicated client scope.
#. Select **Add mapper**, then **By configuration**.
#. Select **Group Membership**.
#. Configure the mapper as follows::

      Name: groups
      Token Claim Name: groups
      Full group path: Off
      Add to ID token: On
      Add to access token: On
      Add to userinfo: On

#. Save the mapper.

With **Full group path** disabled, a member of ``platform-admins`` receives
``platform-admins`` in the claim rather than ``/platform-admins``. Argo CD RBAC
group names must use the same format emitted by this mapper.

Configure Argo CD
-----------------

Argo CD reads its external URL and OIDC provider configuration from
``argocd-cm``. The working configuration is::

   data:
     url: https://argocd.44.203.188.20.nip.io
     oidc.config: |
       name: Keycloak
       issuer: http://keycloak.44.203.188.20.nip.io/realms/genome
       clientID: argocd
       enablePKCEAuthentication: true
       requestedScopes:
         - openid
       usernameClaim: preferred_username

Only the mandatory ``openid`` scope is requested. The mapper on
``argocd-dedicated`` adds the ``groups`` claim directly to the issued tokens,
so a separate requested ``groups`` scope is not required for this setup. Add
``profile`` or ``email`` only after their Keycloak client scopes and token
mappers have been configured.

The current setup was applied manually::

   kubectl -n argocd patch configmap argocd-cm \
     --type merge \
     -p '{"data":{"url":"https://argocd.44.203.188.20.nip.io","oidc.config":"name: Keycloak\nissuer: http://keycloak.44.203.188.20.nip.io/realms/genome\nclientID: argocd\nenablePKCEAuthentication: true\nrequestedScopes:\n  - openid\nusernameClaim: preferred_username"}}'

Restart Argo CD server after changing the ConfigMap::

   kubectl -n argocd rollout restart deployment argocd-server
   kubectl -n argocd rollout status deployment argocd-server --timeout=5m

.. note::

   Because this public-client configuration uses PKCE, do not add a client
   secret to ``argocd-secret``. A confidential Keycloak client is a different
   configuration and must not be mixed with this procedure.

HTTP issuer in this POC
-----------------------

The issuer is HTTP because the Keycloak HTTPS endpoint currently uses a
certificate that cluster clients do not trust. Argo CD itself remains exposed
to users over HTTPS.

This is a POC workaround. Production deployments should install a trusted
certificate for Keycloak, change the realm's advertised issuer to HTTPS, and
update ``argocd-cm`` at the same time. The issuer must exactly match the
``issuer`` returned by Keycloak's discovery document.

Verify the configuration
------------------------

Check the discovery document::

   curl -fsS \
     http://keycloak.44.203.188.20.nip.io/realms/genome/.well-known/openid-configuration | \
     jq -r '.issuer, .authorization_endpoint, .token_endpoint'

Check the active Argo CD configuration::

   kubectl -n argocd get configmap argocd-cm \
     -o jsonpath='{.data.url}{"\n"}{.data.oidc\.config}{"\n"}'
   kubectl -n argocd logs deployment/argocd-server --tail=100 | \
     grep -Ei 'oidc|sso|keycloak|error'

Open ``https://argocd.44.203.188.20.nip.io``, select **LOGIN WITH
KEYCLOAK**, authenticate, and confirm that Keycloak returns the browser to
``/auth/callback``.

RBAC after authentication
-------------------------

Keycloak proves the user's identity; Argo CD RBAC controls what that identity
may do. ``argocd/bootstrap/02-argocd-rbac-cm.yaml`` defines repository-managed
roles and user/group mappings. The Group Membership mapper described above is
required for those group mappings: the group name in ``argocd-rbac-cm`` must
exactly match a value in the token's ``groups`` claim.

Verify the claim after login without publishing the token. Inspect the browser
session through an approved JWT decoder, or temporarily increase Argo CD OIDC
logging, and confirm the ID token contains a claim similar to::

   "groups": [
     "platform-admins"
   ]

Troubleshooting
---------------

``Invalid parameter: redirect_uri``
   Confirm that both callback URLs are registered exactly and that
   ``argocd-cm.data.url`` contains the same HTTPS origin.

``Missing parameter: code_challenge_method``
   Confirm ``enablePKCEAuthentication: true`` in Argo CD and ``S256`` on the
   Keycloak client.

``unauthorized_client``
   Confirm Client authentication is **Off**. Do not configure a client secret
   when using this public PKCE client.

``invalid_scope``
   Start with only ``openid``. Request additional scopes only after configuring
   their Keycloak client scopes and token mappers.

Login succeeds but permissions are missing
   Confirm the ``groups`` mapper is attached to ``argocd-dedicated``, enabled
   for the ID token, and emitting the same short group name used by
   ``argocd-rbac-cm``. If **Full group path** is enabled, either disable it or
   update the RBAC mapping to include the leading path.

Issuer or discovery failure
   Compare the configured issuer with the discovery document's ``issuer``
   value. They must match exactly, including the scheme and realm.

Configuration ownership
-----------------------

The Keycloak realm/client and ``argocd-cm`` OIDC settings are currently manual
cluster state. They must be recreated after rebuilding Argo CD unless they are
migrated to a secure declarative workflow. The Argo CD RBAC ConfigMap remains
Git-managed.
