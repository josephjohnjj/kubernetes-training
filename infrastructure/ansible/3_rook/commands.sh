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