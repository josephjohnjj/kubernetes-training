
helm repo add fluent https://fluent.github.io/helm-charts
helm repo update

kubectl create ns fluentbit

helm install fluent-bit fluent/fluent-bit -n fluentbit
helm upgrade fluent-bit fluent/fluent-bit -f values.yaml -n fluentbit


