
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts

helm install jaeger jaegertracing/jaeger   -n observability   --create-namespace

kubectl patch svc jaeger -n observability   -p '{"spec":{"type":"NodePort"}}'

kubectl run curl --rm -it   --image=curlimages/curl   --restart=Never -- sh
