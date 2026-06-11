helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/

helm upgrade --install metrics-server metrics-server/metrics-server

helm upgrade --install metrics-server metrics-server/metrics-server \
    --namespace kube-system \
    --set args="{--secure-port=10251,--kubelet-insecure-tls}" \
    --set containerPort=10251

ubectl top pods -n kube-system