



kubectl create -f storage-manifests/keycloak-pool.yaml
kubectl create -f storage-manifests/keycloak-sc.yaml


kubectl patch storageclass keycloak-sc -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

# Keycloak is deployed by the Argo CD Application defined in
# argocd/infrastructure/identity/keycloak/01-keycloak.yaml.
kubectl -n argocd get application keycloak
kubectl -n keycloak get statefulset,service,pod

kubectl patch storageclass keycloak-sc -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
