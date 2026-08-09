



kubectl patch storageclass opensearch-sc \
  -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

helm repo add opensearch https://opensearch-project.github.io/helm-charts/
helm repo update
helm search repo opensearch

helm install opensearch opensearch/opensearch  -f values_opensearch.yaml -n opensearch
helm install opensearch-dashboard opensearch/opensearch-dashboards  -n opensearch

kubectl patch svc opensearch-dashboard-opensearch-dashboards -n opensearch -p '{"spec":{"type":"NodePort"}}'

kubectl patch storageclass opensearch-sc \
  -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'