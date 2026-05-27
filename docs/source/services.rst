Services
============

Designed and managed Kubernetes Services for reliable service discovery, internal communication, and external application exposure across 
containerized workloads.


.. code-block:: bash

    kubectl create ns accounting

Lets create a yaml file for deployment `nginx-one.yaml`:

.. code-block:: yaml

    apiVersion: apps/v1

    kind: Deployment

    metadata:
      name: nginx-one
      namespace: accounting
    

      labels:
        system: secondary

    spec:
      replicas: 2

      selector:
        matchLabels:
          system: secondary

      template:
        metadata:
          labels:
            system: secondary

        spec:
          nodeSelector:
            system: secondOne

          containers:
            - name: nginx
              image: nginx:1.20.1
              imagePullPolicy: Always

              ports:
                - containerPort: 8080
                  protocol: TCP


.. code-block:: bash


    kubectl create -f nginx-one.yaml 


The status of the pods will show as `Pending`

.. code-block:: bash

    kubectl -n accounting get pods

    NAME                         READY   STATUS    RESTARTS   AGE
    nginx-one-599887bddb-5frvw   0/1     Pending   0          48s
    nginx-one-599887bddb-sb4n4   0/1     Pending   0          48s


This because the deployment expects a set of nodes selector labelled as `secondOne`



.. code-block:: bash

    kubectl -n accounting get pods


    Events:
    Type     Reason            Age    From               Message
    ----     ------            ----   ----               -------
    Warning  FailedScheduling  3m10s  default-scheduler  0/3 nodes are available: 1 node(s) had untolerated taint(s), 2 node(s) didn't match Pod's node affinity/selector. no new claims to deallocate, preemption: 0/3 nodes are available: 3 Preemption is not helpful for scheduling.

Let us label one node as `secondOne`

.. code-block:: bash

    kubectl get nodes

    NAME               STATUS   ROLES           AGE   VERSION
    ip-172-31-17-15    Ready    control-plane   98d   v1.35.4
    ip-172-31-29-155   Ready    <none>          98d   v1.35.4
    ip-172-31-31-226   Ready    <none>          98d   v1.35.4

.. code-block:: bash

    kubectl label node ip-172-31-31-226 system=secondary

    node/ip-172-31-31-226 labeled

.. code-block:: bash

    kubectl -n accounting get pods

    NAME                         READY   STATUS    RESTARTS   AGE
    nginx-one-599887bddb-5frvw   1/1     Running   0          8m26s
    nginx-one-599887bddb-sb4n4   1/1     Running   0          8m26s

.. code-block:: bash

    kubectl get nodes --show-labels

    NAME               STATUS   ROLES           AGE   VERSION   LABELS
    ip-172-31-17-15    Ready    control-plane   98d   v1.35.4   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/arch=amd64,kubernetes.io/hostname=ip-172-31-17-15,kubernetes.io/os=linux,node-role.kubernetes.io/control-plane=,node.kubernetes.io/exclude-from-external-load-balancers=
    ip-172-31-29-155   Ready    <none>          98d   v1.35.4   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/arch=amd64,kubernetes.io/hostname=ip-172-31-29-155,kubernetes.io/os=linux
    ip-172-31-31-226   Ready    <none>          98d   v1.35.4   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/arch=amd64,kubernetes.io/hostname=ip-172-31-31-226,kubernetes.io/os=linux,system=secondOne

Now we expose the deployment

.. code-block:: bash

    kubectl -n accounting expose deployment nginx-one

    service/nginx-one exposed

.. code-block:: bash

    kubectl -n accounting get ep nginx-one

    Warning: v1 Endpoints is deprecated in v1.33+; use discovery.k8s.io/v1 EndpointSlice
    NAME        ENDPOINTS                                   AGE
    nginx-one   192.168.214.137:8080,192.168.214.138:8080   52s


Let us try the curl command to see if the deployment exposure has worked


.. code-block:: bash

    curl 192.168.214.137:8080

    curl: (7) Failed to connect to 192.168.214.137 port 8080 after 1 ms: Couldn't connect to server


While the port 8080 fail, we can see that port 80 works


.. code-block:: bash

    curl 192.168.214.137:80

    <!DOCTYPE html>
    <html>
    <head>
    <title>Welcome to nginx!</title>
    <style>
        body {
            width: 35em;
            margin: 0 auto;
            font-family: Tahoma, Verdana, Arial, sans-serif;
        }
    </style>
    </head>
    <body>
    <h1>Welcome to nginx!</h1>
    <p>If you see this page, the nginx web server is successfully installed and
    working. Further configuration is required.</p>

    <p>For online documentation and support please refer to
    <a href="http://nginx.org/">nginx.org</a>.<br/>
    Commercial support is available at
    <a href="http://nginx.com/">nginx.com</a>.</p>

    <p><em>Thank you for using nginx.</em></p>
    </body>
    </html>


The issue is a mismatch between Kubernetes configuration and what the container is actually doing. Although `containerPort: 8080` is set, this does 
not make nginx listen on that port—it only serves as metadata. In reality, nginx is running on port 80, which is why `curl` to port 80 works but 
port 8080 fails. The Kubernetes Service or Endpoints are incorrectly routing traffic to port 8080, while the application is only listening on port 80. 

To fix this, either update the Service to use `containerPort: 80`

.. code-block:: yaml
    
    apiVersion: apps/v1

    kind: Deployment

    metadata:
      name: nginx-one
      namespace: accounting
    

      labels:
        system: secondary

    spec:
      replicas: 2

      selector:
        matchLabels:
          system: secondary

      template:
        metadata:
          labels:
            system: secondary

        spec:
          nodeSelector:
            system: secondOne

          containers:
            - name: nginx
              image: nginx:1.20.1
              imagePullPolicy: Always

              ports:
                - containerPort: 80
                  protocol: TCP






.. code-block:: bash

    kubectl delete deploy nginx-one -n accounting

    kubectl create -f nginx-one.yaml


.. code-block:: bash

    kubectl -n accounting edit svc nginx-one



Now edit the service as well:

.. code-block:: yaml


      ports:
      - port: 80
        protocol: TCP
        targetPort: 80


.. code-block:: bash
    
    kubectl -n accounting get ep nginx-one

    Warning: v1 Endpoints is deprecated in v1.33+; use discovery.k8s.io/v1 EndpointSlice
    NAME        ENDPOINTS                               AGE
    nginx-one   192.168.214.141:80,192.168.214.142:80   24m