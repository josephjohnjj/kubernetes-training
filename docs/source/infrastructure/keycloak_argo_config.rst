Configure Argo CD as a Keycloak OIDC Client
================================================

This document describes how to configure **Keycloak** as the OpenID Connect (OIDC) identity provider for **Argo CD**.

## Environment

+----------------------+--------------------------------------------------------------+
| Component            | Value                                                        |
+======================+==============================================================+
| Keycloak             | http://keycloak.44.203.188.20.nip.io                         |
+----------------------+--------------------------------------------------------------+
| Keycloak Realm       | genome                                                       |
+----------------------+--------------------------------------------------------------+
| Argo CD              | https://argocd.44.203.188.20.nip.io                          |
+----------------------+--------------------------------------------------------------+
| Keycloak Client ID   | argocd                                                       |
+----------------------+--------------------------------------------------------------+
| Authentication       | OpenID Connect                                               |
+----------------------+--------------------------------------------------------------+
| PKCE                 | S256                                                         |
+----------------------+--------------------------------------------------------------+

Create the Keycloak Client
-----------------------------



Log in to the Keycloak Admin Console and switch to the `genome` realm.

Navigate to::

```
Clients → Create client
```

Configure::

```
Client type: OpenID Connect
Client ID: argocd
```

The client should be configured as a **public client** because Argo CD is using PKCE.

Capability configuration

```

Set::

    Client authentication: OFF
    Standard flow: ON

The important setting is::

    Client authentication: OFF

With PKCE, Argo CD does not require a client secret for the browser authentication flow.


Configure the Client URLs
----------------------------

Configure the client with the following values.

Root URL
~~~~~~~~

::

    https://argocd.44.203.188.20.nip.io

Home URL
~~~~~~~~

::

    https://argocd.44.203.188.20.nip.io

Valid redirect URIs
~~~~~~~~~~~~~~~~~~~

Add::

    https://argocd.44.203.188.20.nip.io/auth/callback

Also add the PKCE verification endpoint::

    https://argocd.44.203.188.20.nip.io/pkce/verify

The resulting configuration should contain::

    https://argocd.44.203.188.20.nip.io/auth/callback
    https://argocd.44.203.188.20.nip.io/pkce/verify

Web origins
~~~~~~~~~~~

Set::

    https://argocd.44.203.188.20.nip.io


Configure PKCE
-----------------

Configure the Keycloak client to use::

    Proof Key for Code Exchange Code Challenge Method: S256

PKCE protects the authorization-code flow without requiring Argo CD to expose a client secret to the browser.

The resulting configuration is::

    Client ID:
    argocd

    Client authentication:
    OFF

    Standard flow:
    ON

    PKCE:
    S256


Keycloak OIDC Issuer
-----------------------

The OIDC issuer is the URL of the ``genome`` realm::

    http://keycloak.44.203.188.20.nip.io/realms/genome

The OpenID Connect discovery document is available at::

    http://keycloak.44.203.188.20.nip.io/realms/genome/.well-known/openid-configuration

The discovery document contains the endpoints that Argo CD uses for authentication.


Argo CD OIDC Configuration
-----------------------------

Argo CD uses the ``argocd-cm`` ConfigMap for its OIDC configuration.

Edit the ConfigMap::

    kubectl edit configmap argocd-cm -n argocd

The relevant configuration is::

    data:
      url: https://argocd.44.203.188.20.nip.io

      oidc.config: |
        name: Keycloak
        issuer: http://keycloak.44.203.188.20.nip.io/realms/genome
        clientID: argocd
        enablePKCEAuthentication: true
        requestedScopes:
          - openid

The important settings are::

    name: Keycloak

::

    issuer: http://keycloak.44.203.188.20.nip.io/realms/genome

::

    clientID: argocd

::

    enablePKCEAuthentication: true

and::

    requestedScopes:
      - openid


Why Only ``openid`` Is Requested
-----------------------------------

Initially, only the mandatory OIDC scope should be requested::

    requestedScopes:
      - openid

Additional scopes such as::

    profile
    email
    groups

can be added later after the corresponding Keycloak client scopes and claims have been configured.

For example, eventually the configuration may request::

    requestedScopes:
      - openid
      - profile
      - email
      - groups

The ``groups`` scope is particularly useful when integrating Keycloak groups with Argo CD RBAC.


Restart Argo CD
------------------

After modifying ``argocd-cm``, restart the Argo CD server::

    kubectl -n argocd rollout restart deployment argocd-server

Wait for the deployment::

    kubectl -n argocd rollout status deployment argocd-server

Expected output::

    deployment "argocd-server" successfully rolled out


Verify the Argo CD Configuration
-----------------------------------

Check the external URL::

    kubectl get configmap argocd-cm -n argocd \
      -o jsonpath='{.data.url}{"\n"}'

Expected::

    https://argocd.44.203.188.20.nip.io

Check the OIDC configuration::

    kubectl get configmap argocd-cm -n argocd \
      -o jsonpath='{.data.oidc\.config}{"\n"}'

Expected::

    name: Keycloak
    issuer: http://keycloak.44.203.188.20.nip.io/realms/genome
    clientID: argocd
    enablePKCEAuthentication: true
    requestedScopes:
      - openid


Verify Argo CD Logs
----------------------

Check the Argo CD server logs::

    kubectl -n argocd logs deployment/argocd-server --tail=100

Useful messages include::

    Creating client app (argocd)

and::

    argocd v3.5.0 serving on port 8080
    ...
    sso: true

The ``sso: true`` message indicates that SSO has been enabled.


Test the Login
------------------

Open::

    https://argocd.44.203.188.20.nip.io

Select::

    LOGIN WITH KEYCLOAK

Argo CD should redirect to the Keycloak ``genome`` realm.

The authentication flow is::

    User
      |
      v
    Argo CD
      |
      | OIDC + PKCE
      v
    Keycloak
      |
      | genome realm
      v
    User authentication
      |
      v
    Authorization code
      |
      v
    Argo CD
      |
      v
    Argo CD RBAC

The Keycloak username and password are **not validated by Argo CD**. Keycloak performs the authentication.


Troubleshooting
-------------------

``Client not found``
~~~~~~~~~~~~~~~~~~~~

If Keycloak reports::

    Client not found

check that the Argo CD configuration uses::

    clientID: argocd

and that Keycloak contains a client with exactly::

    Client ID: argocd

The client ID is case-sensitive.


``Invalid redirect URL``
```

Verify the Keycloak client contains::

```
https://argocd.44.203.188.20.nip.io/auth/callback
```

and::

```
https://argocd.44.203.188.20.nip.io/pkce/verify
```

Also verify Argo CD's external URL::

```
kubectl get configmap argocd-cm -n argocd \
  -o jsonpath='{.data.url}{"\n"}'
```

It should return::

```
https://argocd.44.203.188.20.nip.io
```

`invalid_scope`

```

If Keycloak reports::

    invalid_scope

start with only::

    requestedScopes:
      - openid

Additional scopes should only be added after the corresponding Keycloak configuration has been created.


``Missing parameter: code_challenge_method``
```

Make sure Argo CD has::

```
enablePKCEAuthentication: true
```

and the Keycloak client is configured for::

```
PKCE: S256
```

`unauthorized_client`

```

If Keycloak reports::

    unauthorized_client
    Invalid client or Invalid client credentials

check::

    Client authentication: OFF

for the ``argocd`` Keycloak client when using the PKCE/public-client configuration.


Authentication vs Authorization
-----------------------------------

Successful Keycloak login only establishes **authentication**.

It answers:

    Who is this user?

Argo CD RBAC determines:

    What can this user do?

The overall architecture is::

                     Keycloak
                         |
                   Authentication
                         |
                         v
                     Argo CD
                         |
                   Authorization
                         |
                         v
                    Argo CD RBAC
                         |
               +---------+---------+
               |                   |
               v                   v
          Applications          Projects

The next step should be configuring Keycloak groups and mapping them to Argo CD RBAC roles.

For a multi-GEN3 environment, a recommended structure is::

    Keycloak
    |
    +-- platform-admins
    |
    +-- gen3-1000g-admins
    +-- gen3-1000g-users
    |
    +-- gen3-cancer-admins
    +-- gen3-cancer-users

These groups can eventually be mapped to Argo CD roles that restrict users to their respective GEN3 applications.
```
