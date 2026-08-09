
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

Fluent Bit
---------

```bash
helm repo add fluent https://fluent.github.io/helm-charts
helm repo update

kubectl create ns fluentbit

helm install fluent-bit fluent/fluent-bit -n fluentbit
helm upgrade fluent-bit fluent/fluent-bit -f fluentbit_values.yaml -n fluentbit
```

Prometheus Stack
--------------------

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

kubectl create namespace prometheus

helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace prometheus
```

Metric Server
---------------

```bash
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/

helm upgrade --install metrics-server metrics-server/metrics-server

helm upgrade --install metrics-server metrics-server/metrics-server \
    --namespace kube-system \
    --set args="{--secure-port=10251,--kubelet-insecure-tls}" \
    --set containerPort=10251

kubectl top pods -n kube-system
```

Rook-Ceph
-----------

```bash
helm repo add rook-release https://charts.rook.io/release
helm repo add ceph-csi-operator https://ceph.github.io/ceph-csi-operator


helm install --create-namespace --namespace rook-ceph rook-ceph rook-release/rook-ceph -f https://raw.githubusercontent.com/rook/rook/master/deploy/charts/rook-ceph/values.yaml
helm install ceph-csi-drivers --namespace rook-ceph ceph-csi-operator/ceph-csi-drivers   -f https://raw.githubusercontent.com/rook/rook/master/deploy/charts/ceph-csi-drivers/values.yaml

kubectl get csidrivers

kubectl create -f cluster.yaml


kubectl -n rook-ceph get cephcluster

kubectl create -f toolbox.yaml 

kubectl -n rook-ceph get service

kubectl -n rook-ceph get secret rook-ceph-dashboard-password -o jsonpath="{['data']['password']}" | base64 --decode && echo

n9!,6YZ9U#@H2PFN0&!

kubectl -n rook-ceph delete pod -l app=rook-ceph-operator

kubectl create -f scratch-fs.yaml 

kubectl -n rook-ceph get cephfilesystem 

kubectl create -f scratch-sc.yaml 

kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph fs ls

kubectl create namespace mlproject
```












