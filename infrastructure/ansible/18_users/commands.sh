

kubectl create namespace gpu-users
kubectl create namespace cpu-users
kubectl create namespace admin-users

kubectl create clusterrolebinding admin-user \
  --clusterrole=cluster-admin \
  --user=admin

openssl genrsa -out alice.key 2048
openssl req -new \
  -key alice.key \
  -out alice.csr \
  -subj "/CN=alice/O=gpu-users"

openssl x509 -req \
  -in alice.csr \
  -CA /etc/kubernetes/pki/ca.crt \
  -CAkey /etc/kubernetes/pki/ca.key \
  -CAcreateserial \
  -out alice.crt \
  -days 365

sudo openssl x509 -req   -in alice.csr   -CA /etc/kubernetes/pki/ca.crt   -CAkey /etc/kubernet
es/pki/ca.key   -CAcreateserial   -out alice.crt   -days 365
Certificate request self-signature ok
subject=CN = alice, O = gpu-users


openssl genrsa -out bob.key 2048

openssl req -new \
  -key bob.key \
  -out bob.csr \
  -subj "/CN=bob/O=cpu-users"

sudo openssl x509 -req \
  -in bob.csr \
  -CA /etc/kubernetes/pki/ca.crt \
  -CAkey /etc/kubernetes/pki/ca.key \
  -CAcreateserial \
  -out bob.crt \
  -days 365
Certificate request self-signature ok
subject=CN = bob, O = cpu-users

kubectl config view


kubectl config set-cluster my-cluster \
  --server=https://10.0.1.209:6443 \
  --certificate-authority=/etc/kubernetes/pki/ca.crt \
  --kubeconfig=alice.config

kubectl config set-credentials alice \
  --client-certificate=alice.crt \
  --client-key=alice.key \
  --kubeconfig=alice.config


kubectl config set-context alice-context \
  --cluster=my-cluster \
  --user=alice \
  --kubeconfig=alice.config

kubectl config use-context alice-context \
  --kubeconfig=alice.config


kubectl config set-cluster my-cluster \
  --server=https://10.0.1.209:6443 \
  --certificate-authority=/etc/kubernetes/pki/ca.crt \
  --kubeconfig=bob.config

kubectl config set-credentials bob \
  --client-certificate=bob.crt \
  --client-key=bob.key \
  --kubeconfig=bob.config


kubectl config set-context bob-context \
  --cluster=my-cluster \
  --user=bob \
  --kubeconfig=bob.config


kubectl config use-context bob-context \
  --kubeconfig=bob.config





