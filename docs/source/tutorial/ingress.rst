Ingress Control
==================

In Kubernetes, **Ingress control** refers to the mechanism that manages external HTTP/HTTPS traffic
into a cluster and routes it to the appropriate internal services. Instead of exposing every service
with its own public IP, an Ingress provides a single entry point and uses rules (based on hostnames or
URL paths) to direct traffic—for example, routing `api.example.com` to an API service and
`app.example.com` to a frontend service.

The Ingress resource itself is just a set of routing rules; it only works when paired with an
**Ingress Controller**, which is the actual component that implements those rules. Common controllers
include the NGINX Ingress Controller and Traefik. These controllers continuously watch the Kubernetes
API, configure a reverse proxy (like NGINX or Traefik), and handle load balancing, SSL termination,
and request routing into the cluster. In short: Ingress defines *what should happen*, and the
controller makes it *actually happen*.


Create two deployments running nginx (`web-one.yaml` and `web-two.yaml`).


.. code-block:: yaml

    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: web-one
    spec:
      replicas: 1
      selector:
        matchLabels:
          app: web-one
      template:
        metadata:
          labels:
            app: web-one
        spec:
          containers:
          - name: nginx
            image: nginx:latest
            ports:
            - containerPort: 80


.. code-block:: yaml

    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: web-two
    spec:
      replicas: 1
      selector:
        matchLabels:
          app: web-two
      template:
        metadata:
          labels:
            app: web-two
        spec:
          containers:
          - name: nginx
            image: nginx:latest
            ports:
            - containerPort: 80


.. code-block:: bash

    kubectl apply -f web-one.yaml
    kubectl apply -f web-two.yaml


Expose both as ClusterIP services (`web-one-svc.yaml` and `web-two-svc.yaml`).

.. code-block:: yaml

    apiVersion: v1
    kind: Service
    metadata:
      name: web-one-svc
    spec:
      selector:
        app: web-one
      ports:
      - port: 80
        targetPort: 80
      type: ClusterIP


.. code-block:: yaml

    apiVersion: v1
    kind: Service
    metadata:
      name: web-two-svc
    spec:
      selector:
        app: web-two
      ports:
      - port: 80
        targetPort: 80
      type: ClusterIP


.. code-block:: bash

    kubectl apply -f web-one-svc.yaml
    kubectl apply -f web-two-svc.yaml


.. code-block:: bash

    helm search hub ingress
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    helm repo update
    helm fetch ingress-nginx/ingress-nginx --untar


.. code-block:: bash

    cd ingress-nginx
    ls
    Chart.yaml  OWNERS  README.md  README.md.gotmpl  changelog  ci  cloudbuild.yaml  templates  tests  values.yaml


Edit `values.yaml` and change the `kind` to `DaemonSet`.

.. code-block:: bash

    helm install myingress .


.. code-block:: bash

    kubectl get daemonset

    NAME                                 DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR            AGE
    myingress-ingress-nginx-controller   2         2         2       2            2           kubernetes.io/os=linux   51s


We now have an **Ingress controller** running, but no rules yet.

.. code-block:: bash

    kubectl get ingress --all-namespaces

    No resources found


.. code-block:: bash

    kubectl --namespace default get services -o wide myingress-ingress-nginx-controller

    NAME                                 TYPE           CLUSTER-IP       EXTERNAL-IP   PORT(S)                      AGE   SELECTOR
    myingress-ingress-nginx-controller   LoadBalancer   10.103.219.222   <pending>     80:32536/TCP,443:30369/TCP   10m   app.kubernetes.io/component=controller,app.kubernetes.io/instance=myingress,app.kubernetes.io/name=ingress-nginx


.. code-block:: bash

    kubectl get pod --all-namespaces | grep nginx

    default       myingress-ingress-nginx-controller-hbdjq          1/1     Running     0             16m
    default       myingress-ingress-nginx-controller-lfw9l          1/1     Running     0             16m
    default       nginx-56c45fd5ff-lq9wx                            1/1     Running     0             25h


Create a file `ingress.yaml`

.. code-block:: yaml

    apiVersion: networking.k8s.io/v1
    kind: Ingress
    metadata:
      name: ingress-test
      namespace: default
      annotations:
        nginx.ingress.kubernetes.io/service-upstream: "true"

    spec:
      ingressClassName: nginx
      rules:
      - host: www.external.com
        http:
          paths:
          - path: /
            pathType: ImplementationSpecific
            backend:
              service:
                name: web-one-svc
                port:
                  number: 80


.. code-block:: bash

    kubectl create -f ingress.yaml

    ingress.networking.k8s.io/ingress-test created


.. code-block:: bash

    kubectl get ingress

    NAME           CLASS   HOSTS              ADDRESS   PORTS   AGE
    ingress-test   nginx   www.external.com             80      51s


Now we can see an ingress rule running for `www.external.com`.

.. code-block:: bash

    kubectl get pod -o wide | grep myingress
    myingress-ingress-nginx-controller-hbdjq          1/1     Running     0          28m     192.168.244.54    ip-172-31-29-155   <none>           <none>
    myingress-ingress-nginx-controller-lfw9l          1/1     Running     0          28m     192.168.214.173   ip-172-31-31-226   <none>           <none>


.. code-block:: bash

    curl 192.168.244.54

    <html>
    <head><title>404 Not Found</title></head>
    <body>
    <center><h1>404 Not Found</h1></center>
    <hr><center>nginx</center>
    </body>
    </html>


.. code-block:: bash

    curl 192.168.214.173

    <html>
    <head><title>404 Not Found</title></head>
    <body>
    <center><h1>404 Not Found</h1></center>
    <hr><center>nginx</center>
    </body>
    </html>


.. code-block:: bash

    kubectl get svc | grep ingress

    myingress-ingress-nginx-controller             LoadBalancer   10.103.219.222   <pending>     80:32536/TCP,443:30369/TCP   32m
    myingress-ingress-nginx-controller-admission   ClusterIP      10.106.34.33     <none>        443/TCP                      32m


Now let's check the service again:

.. code-block:: bash

    curl 10.103.219.222

    <html>
    <head><title>404 Not Found</title></head>
    <body>
    <center><h1>404 Not Found</h1></center>
    <hr><center>nginx</center>
    </body>
    </html>


Now let's pass a header which matches a URL to one of the services we exposed earlier.

.. code-block:: bash

    curl -H "Host: www.external.com" 10.103.219.222

    <html>
    <head><title>503 Service Temporarily Unavailable</title></head>
    <body>
    <center><h1>503 Service Temporarily Unavailable</h1></center>
    <hr><center>nginx</center>
    </body>
    </html>


This command works as the host is allowed by the ingress rules.

.. code-block:: bash

    curl -H "Host: www.external.com" http://10.103.219.222/

    <!DOCTYPE html>
    <html>
    <head>
    <title>Welcome to nginx!</title>
    ...
    </html>


Now test if `web-two` will work. This won't, as there are no ingress rules defined. So we will edit the existing ingress rule.

.. code-block:: bash

    curl -H "Host: www.external.com" http://10.103.219.222/


Now edit the ingress rule:

.. code-block:: bash

    kubectl edit ingress ingress-test


.. code-block:: yaml

    apiVersion: networking.k8s.io/v1
    kind: Ingress
    metadata:
      name: ingress-test
      namespace: default
      annotations:
        nginx.ingress.kubernetes.io/service-upstream: "true"

    spec:
      ingressClassName: nginx
      rules:
      - host: www.internal.com
        http:
          paths:
          - path: /
            pathType: ImplementationSpecific
            backend:
              service:
                name: web-two-svc
                port:
                  number: 80


.. code-block:: bash

    curl -H "Host: www.internal.com" http://10.103.219.222/

    <!DOCTYPE html>
    <html>
    <head>
    <title>Welcome to nginx!</title>
    ...
    </html>