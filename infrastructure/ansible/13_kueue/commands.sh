
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