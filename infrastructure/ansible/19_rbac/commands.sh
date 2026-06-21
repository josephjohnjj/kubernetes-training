 
kubectl create -f gpu-roles.yaml 
kubectl create -f cpu-roles.yaml

kubectl create -f gpu-binding.yaml 
kubectl create -f cpu-binding.yaml 

kubectl --kubeconfig=alice.config get pods -n gpu-users

kubectl --kubeconfig=alice.config get pods -n cpu-users

kubectl auth whoami

kubectl auth can-i create pods -n gpu-users --as=bob