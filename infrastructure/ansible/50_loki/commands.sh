
helm repo add grafana-community https://grafana-community.github.io/helm-charts
helm repo update


kubectl create namespace loki

kubectl create -f minio-pool.yaml 
kubectl -n rook-ceph get cephblockpool 

kubectl create -f minio-sc.yaml 
kubectl -n rook-ceph get sc

helm install --values values.yaml loki grafana-community/loki -n loki

