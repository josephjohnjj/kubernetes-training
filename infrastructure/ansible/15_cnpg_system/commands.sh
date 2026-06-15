

kubectl create -f cnpg-pool.yaml 
kubectl create -f cnpg-sc.yaml 

kubectl patch storageclass cnpg-sc   -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'


helm repo add cnpg https://cloudnative-pg.github.io/charts

helm upgrade --install cnpg --namespace cnpg-system --create-namespace cnpg/cloudnative-pg

helm upgrade --install cnpg --namespace cnpg-database --create-namespace --values values.yaml cnpg/cluster

