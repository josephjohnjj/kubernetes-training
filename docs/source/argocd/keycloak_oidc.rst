Manual Keycloak OIDC Integration for Argo CD
============================================

Argo CD login was linked manually to a Keycloak user. This is a bootstrap and
identity configuration step, not currently a fully Git-managed workflow.

Keycloak configuration
----------------------

Keycloak realm ``infrastructure`` contains an OpenID Connect client with:

* Client ID ``argocd-infra``.
* An Argo CD callback URI appropriate for the Argo CD public hostname.
* A generated confidential client secret.
* User identity exposed through claim ``preferred_username``.

The Argo CD issuer is currently::

   http://keycloak.44.203.188.20.nip.io/realms/infrastructure

Use HTTPS and update all issuer and callback URLs together for production.

Create the client Secret
------------------------

The original procedure applied a local ``argocd-keycloak-secret.yaml`` file::

   kubectl apply -f argocd-keycloak-secret.yaml
   kubectl get secret argocd-secret-keycloak -n argocd

The file is not currently present in this repository. A safe template is::

   apiVersion: v1
   kind: Secret
   metadata:
     name: argocd-secret-keycloak
     namespace: argocd
   type: Opaque
   stringData:
     clientSecret: REPLACE_WITH_KEYCLOAK_CLIENT_SECRET

Do not commit the substituted file. Prefer an external or encrypted Secret.

Copy the secret into Argo CD
----------------------------

Argo CD expects the client secret in ``argocd-secret``. The manual command used
was::

   kubectl -n argocd patch secret argocd-secret \
     --type merge \
     -p '{"stringData":{"oidc.keycloak.clientSecret":"'"$(kubectl -n argocd get secret argocd-secret-keycloak -o jsonpath='{.data.clientSecret}' | base64 -d)'""}}'

This command places the decoded value in a process argument. Prefer an external
secret controller in a production implementation. Do not print or record the
decoded value.

Configure ``argocd-cm``
-----------------------

The OIDC configuration was added manually to ConfigMap ``argocd-cm``::

   oidc.config: |
     name: Keycloak
     issuer: http://keycloak.44.203.188.20.nip.io/realms/infrastructure
     clientID: argocd-infra
     enablePKCEAuthentication: true
     requestedScopes:
       - openid
     usernameClaim: preferred_username

It can be applied without opening an editor::

   kubectl -n argocd patch configmap argocd-cm \
     --type merge \
     -p '{"data":{"oidc.config":"name: Keycloak\nissuer: http://keycloak.44.203.188.20.nip.io/realms/infrastructure\nclientID: argocd-infra\nenablePKCEAuthentication: true\nrequestedScopes:\n  - openid\nusernameClaim: preferred_username"}}'

Verify metadata without displaying Secrets::

   kubectl get configmap argocd-cm -n argocd -o yaml
   kubectl -n argocd get secret argocd-secret-keycloak

Restart Argo CD server::

   kubectl -n argocd rollout restart deployment argocd-server
   kubectl -n argocd rollout status deployment argocd-server

RBAC mapping
------------

``argocd/bootstrap/argocd-rbac-cm.yaml`` is Git-managed. It defines role
``infrastructure-admin`` and maps both a Keycloak group and a specific user to
that role. The role can get, sync, update, and delete Applications in project
``infrastructure``. All other authenticated users receive the configured
read-only default role.

Manual versus Git-managed state
-------------------------------

.. list-table::
   :header-rows: 1
   :widths: 50 50

   * - Configuration
     - Ownership
   * - Keycloak realm, client, and user
     - Manual Keycloak administration
   * - ``argocd-secret-keycloak``
     - Manually applied Secret
   * - OIDC value in ``argocd-secret``
     - Manually patched
   * - ``argocd-cm`` OIDC settings
     - Manually patched
   * - ``argocd-rbac-cm`` policy
     - Git-managed under ``argocd/bootstrap``

Because the OIDC settings are manual, they must be repeated after rebuilding
Argo CD unless migrated to a secure declarative mechanism.

