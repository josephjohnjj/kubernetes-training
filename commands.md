
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

Cert-manager
--------------

```bash

kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.20.2/cert-manager.yaml

```

Kubeflow-Trainer
------------------


```bash
helm install kubeflow-trainer oci://ghcr.io/kubeflow/charts/kubeflow-trainer  --namespace kubeflow-system  --create-namespace
```

Kyverno
--------

```bash
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update

helm install kyverno kyverno/kyverno -n kyverno --create-namespace \
--set admissionController.replicas=3 \
--set backgroundController.replicas=2 \
--set cleanupController.replicas=2 \
--set reportsController.replicas=2
```

Kueue
-----

```bash
helm install kueue oci://registry.k8s.io/kueue/charts/kueue \
  --version=0.18.1 \
  --namespace  kueue-system \
  --create-namespace \
  --wait --timeout 300s

kubectl label nodes cpu-worker1 worker-type=cpu 
kubectl label nodes cpu-worker2 worker-type=cpu 
kubectl label nodes gpu-worker1 worker-type=gpu 
kubectl label nodes gpu-worker2 worker-type=gpu 

kubectl create -f cpu_queue.yaml 
kubectl create -f gpu_queue.yaml 


kubectl get localqueues -A
kubectl get clusterqueues
kubectl get resourceflavors
```











