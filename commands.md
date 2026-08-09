
Jaeger
------

```bash
helm repo add jaegertracing https://jaegertracing.github.io/helm-charts

helm install jaeger jaegertracing/jaeger -n jaeger --create-namespace
```

Trivy
--------

```bash
    helm repo add aqua https://aquasecurity.github.io/helm-charts/
    helm repo update

    helm install trivy-operator aqua/trivy-operator \
     --namespace trivy-system \
     --create-namespace \
     --version 0.33.1
```

Falco
------

```bash
    helm repo add falcosecurity https://falcosecurity.github.io/charts
    helm repo update

    helm install --replace falco --namespace falco --create-namespace --set tty=true falcosecurity/falco

    kubectl get pods -n falco

    helm upgrade --namespace falco falco falcosecurity/falco --set falcosidekick.enabled=true --set falcosidekick.webui.enabled=true
```









