Configure Argo CD as a Keycloak OIDC Client
===========================================

The canonical procedure for the current ``genome`` realm, public ``argocd``
client, PKCE settings, callback URLs, Argo CD ConfigMap, verification, and
troubleshooting is documented in :doc:`../argocd/keycloak_oidc`.

Argo CD and GEN3 Fence use separate Keycloak clients. Do not reuse the
``gen3-fence`` client or its callback URLs for Argo CD.
