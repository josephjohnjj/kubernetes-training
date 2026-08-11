
kubectl apply -f argocd-keycloak-secret.yaml

kubectl get secret argocd-secret-keycloak -n argocd


kubectl -n argocd patch secret argocd-secret \
  --type merge \
  -p '{"stringData":{"oidc.keycloak.clientSecret":"'"$(kubectl -n argocd get secret argocd-secret-keycloak -o jsonpath='{.data.clientSecret}' | base64 -d)"'"}}'

kubectl edit configmap argocd-cm -n argocd

# Under data add

  oidc.config: |
    name: Keycloak
    issuer: http://keycloak.44.203.188.20.nip.io/realms/infrastructure
    clientID: argocd-infra
    enablePKCEAuthentication: true
    requestedScopes:
      - openid


kubectl -n argocd patch configmap argocd-cm \
  --type merge \
  -p '{"data":{"oidc.config":"name: Keycloak\nissuer: http://keycloak.44.203.188.20.nip.io/realms/infrastructure\nclientID: argocd-infra\nenablePKCEAuthentication: true\nrequestedScopes:\n  - openid\nusernameClaim: preferred_username"}}'



kubectl get configmap argocd-cm -n argocd -o yaml

kubectl -n argocd rollout restart deployment argocd-server

kubectl -n argocd rollout status deployment argocd-server