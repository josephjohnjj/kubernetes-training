Linkerd
============

A **service mesh** is a dedicated infrastructure layer that manages communication between microservices in a distributed application.
Linkerd is a lightweight service mesh for Kubernetes that works by injecting proxy sidecars into application pods to handle service-to-service
networking. It provides features such as automatic mutual TLS (mTLS) encryption, traffic routing, retries, load balancing, failure detection,
and observability without requiring changes to application code. By managing networking at the infrastructure level, Linkerd improves the security,
reliability, and monitoring of microservices running in Kubernetes clusters.

.. code-block:: bash

    curl -sL run.linkerd.io/install-edge | sh

    export PATH=$PATH:/home/ubuntu/.linkerd2/bin

    echo "export PATH=$PATH:/home/ubuntu/.linkerd2/bin" >> $HOME/.bashrc

    linkerd check --pre

    kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.1/standard-install.yaml

    linkerd install --crds | kubectl apply -f -

    linkerd install | kubectl apply -f -

    linkerd check

    linkerd viz install | kubectl apply -f -

    linkerd viz check

    linkerd viz dashboard &


This will try launching the dashboard on localhost.

.. code-block:: bash

    http://localhost:50750
    Grafana dashboard available at:
    http://localhost:50750/grafana
    Opening Linkerd dashboard in the default browser
    Failed to open Linkerd dashboard automatically
    Visit http://localhost:50750 in your browser to view the dashboard


So, now we need to edit the service and deployment

.. code-block:: bash

    kubectl -n linkerd-viz edit deploy web

    deployment.apps/web edited


Comment the line with spec `- -enforced-host=`

Now edit the http NodePort and type to be a NodePort.

.. code-block:: bash

    kubectl edit svc web -n linkerd-viz

.. code-block:: yaml

    - name: http
      nodePort: 31500
      port: 8084
      protocol: TCP
      targetPort: 8084
    - name: admin
      port: 9994
      protocol: TCP
      targetPort: 9994
    selector:
      component: web
      linkerd.io/extension: viz
    sessionAffinity: None
    type: NodePort


Now we can access the dashboard using the public IP

.. code-block:: bash

    curl ifconfig.io

    3.89.209.243

.. code-block:: text

    http://3.89.209.243:31500


You need to explicitly enable Linkerd on Kubernetes workloads because it does not automatically manage or intercept traffic by default.
By adding a specific annotation (or using `linkerd inject`), you tell Linkerd to add its proxy sidecar to a pod so it can handle
service-to-service communication, security (mTLS), and observability. Without this step, the application runs as a normal Kubernetes workload with
no service mesh features applied.

.. code-block:: bash

    kubectl get nodes

    NAME               STATUS   ROLES           AGE    VERSION
    ip-172-31-17-15    Ready    control-plane   101d   v1.35.4
    ip-172-31-29-155   Ready    <none>          101d   v1.35.4
    ip-172-31-31-226   Ready    <none>          101d   v1.35.4

.. code-block:: bash

    kubectl label node ip-172-31-29-155 system=secondOne

    node/ip-172-31-29-155 labeled

.. code-block:: bash

    kubectl apply -f nginx-one.yaml

    deployment.apps/nginx-one created

.. code-block:: bash

    kubectl -n accounting get deploy nginx-one -o yaml | linkerd inject - | kubectl apply -f -

    deployment "nginx-one" injected

Now if you check the UI, you can see that the namespace and pods are meshed. Generate some traffic to the pods and watch it via the UI.

.. code-block:: bash

    kubectl -n accounting get svc

    NAME          TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)        AGE
    nginx-one     ClusterIP   10.107.194.150   <none>        80/TCP         2d19h
    service-lab   NodePort    10.111.139.54    <none>        80:31475/TCP   24h

.. code-block:: bash

    curl 10.111.139.54