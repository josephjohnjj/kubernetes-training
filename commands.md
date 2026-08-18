ArgoCD
--------

```bash

kubectl apply -f argocd-keycloak-secret.yaml

kubectl get secret argocd-secret-keycloak -n argocd


kubectl -n argocd patch secret argocd-secret \
  --type merge \
  -p '{"stringData":{"oidc.keycloak.clientSecret":"'"$(kubectl -n argocd get secret argocd-secret-keycloak -o jsonpath='{.data.clientSecret}' | base64 -d)"'"}}'

kubectl edit configmap argocd-cm -n argocd

# Under data add

  oidc.config: |
    name: Keycloak
    issuer: http://keycloak.44.203.188.20.nip.io/realms/infrastructure
    clientID: argocd-infra
    enablePKCEAuthentication: true
    requestedScopes:
      - openid


kubectl -n argocd patch configmap argocd-cm \
  --type merge \
  -p '{"data":{"oidc.config":"name: Keycloak\nissuer: http://keycloak.44.203.188.20.nip.io/realms/infrastructure\nclientID: argocd-infra\nenablePKCEAuthentication: true\nrequestedScopes:\n  - openid\nusernameClaim: preferred_username"}}'



kubectl get configmap argocd-cm -n argocd -o yaml

kubectl -n argocd rollout restart deployment argocd-server

kubectl -n argocd rollout status deployment argocd-server
```



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

kubectl create -f storage/rook-ceph/storage/cephfilesystem/02-scratch-fs.yaml

kubectl -n rook-ceph get cephfilesystem 

kubectl create -f storage/rook-ceph/storage/storageclasses/06-scratch-sc.yaml

kubectl -n rook-ceph exec -it deploy/rook-ceph-tools -- ceph fs ls

kubectl create namespace mlproject
```

Nginx
-------

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx

helm repo update

helm install ingress-nginx ingress-nginx/ingress-nginx   --namespace ingress-nginx   --create-namespace
  
```

OpenSearch
--------------

```bash
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

```

CloudNative PG
-------------------

```bash


kubectl create -f storage/rook-ceph/storage/cephpool/01-cnpg-pool.yaml
kubectl create -f storage/rook-ceph/storage/storageclasses/01-cnpg-sc.yaml

kubectl patch storageclass cnpg-sc   -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'


helm repo add cnpg https://cloudnative-pg.github.io/charts

helm upgrade --install cnpg --namespace cnpg-system --create-namespace cnpg/cloudnative-pg

helm upgrade --install cnpg --namespace cnpg-database --create-namespace --values values.yaml cnpg/cluster

# Create database
# -----------------

postgres=# CREATE USER keycloak WITH PASSWORD 'keycloak-pwd';
CREATE ROLE
postgres=# CREATE DATABASE keycloak OWNER keycloak;
CREATE DATABASE
postgres=# GRANT ALL PRIVILEGES ON DATABASE keycloak TO keycloak;
GRANT
postgres=# \c keycloak
You are now connected to database "keycloak" as user "postgres".
keycloak=# ALTER SCHEMA public OWNER TO keycloak;
ALTER SCHEMA
keycloak=# GRANT ALL ON SCHEMA public TO keycloak;
GRANT
keycloak=# ALTER DEFAULT PRIVILEGES IN SCHEMA public
keycloak-# GRANT ALL ON TABLES TO keycloak;
ALTER DEFAULT PRIVILEGES
keycloak=# ALTER DEFAULT PRIVILEGES IN SCHEMA public
keycloak-# GRANT ALL ON SEQUENCES TO keycloak;
ALTER DEFAULT PRIVILEGES
keycloak=# \dn+
                          List of schemas
  Name  |  Owner   |  Access privileges   |      Description       
--------+----------+----------------------+------------------------
 public | keycloak | keycloak=UC/keycloak+| standard public schema
        |          | =U/keycloak          | 
(1 row)



kubectl get secret cnpg-cluster-superuser -n cnpg-database -o jsonpath="{.data.username}" | base64 --decode

kubectl get secret cnpg-cluster-superuser -n cnpg-database -o jsonpath="{.data.password}" | base64 --decode
    


```

Postgres DB
--------------

```bash
sheepdog_gen3=# ALTER SCHEMA public OWNER TO gen3db;
ALTER SCHEMA
sheepdog_gen3=# GRANT ALL ON SCHEMA public TO gen3db;
GRANT
sheepdog_gen3=# \dn+
                       List of schemas
  Name  | Owner  | Access privileges |      Description       
--------+--------+-------------------+------------------------
 public | gen3db | gen3db=UC/gen3db +| standard public schema
        |        | =UC/gen3db        | 
(1 row)
```












