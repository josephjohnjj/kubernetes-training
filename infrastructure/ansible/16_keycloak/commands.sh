



kubectl create -f keycloak-pool.yaml 
kubectl create -f keycloak-sc.yaml 


kubectl patch storageclass keycloak-sc -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'


helm repo add bitnami https://charts.bitnami.com/bitnami
helm search repo bitnami
helm install keycloak bitnami/keycloak --values values.yaml  -n keycloak


kubectl patch svc keycloak -n keycloak -p '{"spec": {"type": "NodePort"}}'

kubectl describe secret keycloak -n keycloak

kubectl patch storageclass keycloak-sc -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'

