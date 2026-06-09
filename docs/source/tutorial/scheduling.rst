Scheduling
=================

Scheduling is the process of assigning pods to nodes. The Kubernetes scheduler is responsible for this task, and it uses a variety of factors 
to determine which node is the best fit for a given pod.

.. code-block:: bash

    kubectl get pods -o wide

    NAME               STATUS   ROLES           AGE    VERSION
    ip-172-31-17-15    Ready    control-plane   106d   v1.35.4
    ip-172-31-29-155   Ready    <none>          106d   v1.35.4
    ip-172-31-31-226   Ready    <none>          106d   v1.35.4


Lets look at the labels and taints of the nodes to understand how the scheduler makes its decisions.

.. code-block:: bash

    kubectl describe nodes |grep -A5 -i label

    Labels:             beta.kubernetes.io/arch=amd64
                        beta.kubernetes.io/os=linux
                        kubernetes.io/arch=amd64
                        kubernetes.io/hostname=ip-172-31-17-15
                        kubernetes.io/os=linux
                        node-role.kubernetes.io/control-plane=
    --
    Labels:             beta.kubernetes.io/arch=amd64
                        beta.kubernetes.io/os=linux
                        kubernetes.io/arch=amd64
                        kubernetes.io/hostname=ip-172-31-29-155
                        kubernetes.io/os=linux
                        system=secondOne
    --
    Labels:             beta.kubernetes.io/arch=amd64
                        beta.kubernetes.io/os=linux
                        kubernetes.io/arch=amd64
                        kubernetes.io/hostname=ip-172-31-31-226
                        kubernetes.io/os=linux
                        system=secondOne



.. code-block:: bash

    kubectl describe nodes |grep -i taint

    Taints:             node-role.kubernetes.io/control-plane:NoSchedule
    Taints:             <none>
    Taints:             <none>

Lets remove the taint from the control-plane node to allow scheduling of pods on it.

.. code-block:: bash

    kubectl taint nodes ip-172-31-17-15 node-role.kubernetes.io/control-plane:NoSchedule-

    node/ip-172-31-17-15 untainted


We can view the number of containers using the command:

.. code-block:: bash

    sudo crictl ps | wc -l

    WARN[0000] Config "/etc/crictl.yaml" does not exist, trying next: "/usr/bin/crictl.yaml" 
    WARN[0000] runtime connect using default endpoints: [unix:///run/containerd/containerd.sock unix:///run/crio/crio.sock unix:///var/run/cri-dockerd.sock]. As the default settings are now deprecated, you should set the endpoint instead. 
    WARN[0000] Image connect using default endpoints: [unix:///run/containerd/containerd.sock unix:///run/crio/crio.sock unix:///var/run/cri-dockerd.sock]. As the default settings are now deprecated, you should set the endpoint instead. 
    8

.. code-block:: bash

    kubectl label nodes ip-172-31-17-15 status=vip
    kubectl label nodes ip-172-31-29-155 status=other
    kubectl label nodes ip-172-31-31-226 status=other


.. code-block:: bash

    kubectl get nodes --show-labels

    NAME               STATUS   ROLES           AGE    VERSION   LABELS
    ip-172-31-17-15    Ready    control-plane   106d   v1.35.4   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/arch=amd64,kubernetes.io/hostname=ip-172-31-17-15,kubernetes.io/os=linux,node-role.kubernetes.io/control-plane=,node.kubernetes.io/exclude-from-external-load-balancers=,status=vip
    ip-172-31-29-155   Ready    <none>          106d   v1.35.4   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/arch=amd64,kubernetes.io/hostname=ip-172-31-29-155,kubernetes.io/os=linux,status=other,system=secondOne
    ip-172-31-31-226   Ready    <none>          106d   v1.35.4   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/arch=amd64,kubernetes.io/hostname=ip-172-31-31-226,kubernetes.io/os=linux,status=other,system=secondOne



Now, let's create a deployment that will be scheduled on the nodes with the label `status=vip`, `vip.yaml`.

.. code-block:: bash

    apiVersion: v1
    kind: Pod
    metadata:
      name: vip

    spec:
      nodeSelector:
        status: vip

      containers:
        - name: vip1
          image: busybox
          args:
            - sleep
            - "1000000"

        - name: vip2
          image: busybox
          args:
            - sleep
            - "1000000"

        - name: vip3
          image: busybox
          args:
            - sleep
            - "1000000"

        - name: vip4
          image: busybox
          args:
            - sleep
            - "1000000"


.. code-block:: bash

    kubectl apply -f vip.yaml

    pod/vip created


.. code-block:: bash

    sudo crictl ps |wc -l
    WARN[0000] Config "/etc/crictl.yaml" does not exist, trying next: "/usr/bin/crictl.yaml" 
    WARN[0000] runtime connect using default endpoints: [unix:///run/containerd/containerd.sock unix:///run/crio/crio.sock unix:///var/run/cri-dockerd.sock]. As the default settings are now deprecated, you should set the endpoint instead. 
    WARN[0000] Image connect using default endpoints: [unix:///run/containerd/containerd.sock unix:///run/crio/crio.sock unix:///var/run/cri-dockerd.sock]. As the default settings are now deprecated, you should set the endpoint instead. 
    13


Now if you change the label of the node to `status=other`, the pod will be scheduled on the worker nodes. If we didn't specify the nodeSelector, the 
pods could be scheduled on any of the nodes, including the control-plane node. 


.. code-block:: bash

    kubectl delete pods vip 

    pod "vip" deleted from default namespace


Taints
--------

Taints are a way to repel pods from being scheduled on a node. A taint consists of a key, value, and effect. The effect can be NoSchedule, 
PreferNoSchedule, or NoExecute.

.. code-block:: bash

    kubectl taint nodes ip-172-31-29-155 ip-172-31-31-226 bubba=value:PreferNoSchedule

    node/ip-172-31-29-155 tainted
    node/ip-172-31-31-226 tainted


.. code-block:: bash

    kubectl describe nodes |grep -i taint

    Taints:             <none>
    Taints:             bubba=value:PreferNoSchedule
    Taints:             bubba=value:PreferNoSchedule


Now let's create a deployment that will be scheduled on the nodes with the taint `bubba=value:PreferNoSchedule`, `taint.yaml`.

.. code-block:: bash

    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: taint-deployment

    spec:
      replicas: 8
      selector:
        matchLabels:
          app: nginx

      template:
        metadata:
          labels:
            app: nginx

        spec:
          containers:
            - name: nginx
              image: nginx:1.20.1
              ports:
                - containerPort: 80


.. code-block:: bash

    kubectl apply -f taint.yaml

    deployment.apps/taint-deployment created


.. code-block:: bash

    kubectl get deployment

    NAME               READY   UP-TO-DATE   AVAILABLE   AGE
    taint-deployment   8/8     8            8           26s


.. code-block:: bash

    kubectl describe  deployment taint-deployment

    Name:                   taint-deployment
    Namespace:              default
    CreationTimestamp:      Wed, 03 Jun 2026 01:56:33 +0000
    Labels:                 <none>
    Annotations:            deployment.kubernetes.io/revision: 1
    Selector:               app=nginx
    Replicas:               8 desired | 8 updated | 8 total | 8 available | 0 unavailable
    StrategyType:           RollingUpdate
    MinReadySeconds:        0
    RollingUpdateStrategy:  25% max unavailable, 25% max surge
    Pod Template:
      Labels:  app=nginx
      Containers:
       nginx:
        Image:         nginx:1.20.1
        Port:          80/TCP
        Host Port:     0/TCP
        Environment:   <none>
        Mounts:        <none>
      Volumes:         <none>
      Node-Selectors:  <none>
      Tolerations:     <none>
    Conditions:
      Type           Status  Reason
      ----           ------  ------
      Available      True    MinimumReplicasAvailable
      Progressing    True    NewReplicaSetAvailable
    OldReplicaSets:  <none>
    NewReplicaSet:   taint-deployment-6bbd58d65d (8/8 replicas created)
    Events:
      Type    Reason             Age   From                   Message
      ----    ------             ----  ----                   -------
      Normal  ScalingReplicaSet  66s   deployment-controller  Scaled up replica set taint-deployment-6bbd58d65d from 0 to 8


Now we use `Labels:  app=nginx` to select the pods that will be scheduled on the nodes with the taint `bubba=value:PreferNoSchedule`. 
The scheduler will try to schedule the pods on the nodes with the taint, but if it cannot find a suitable node, it will schedule the pods on other nodes.


.. code-block:: bash

    kubectl get pods -l app=nginx -o wide

    NAME                                READY   STATUS    RESTARTS   AGE     IP               NODE              NOMINATED NODE   READINESS GATES
    taint-deployment-6bbd58d65d-2nw48   1/1     Running   0          2m30s   192.168.123.15   ip-172-31-17-15   <none>           <none>
    taint-deployment-6bbd58d65d-4lll6   1/1     Running   0          2m30s   192.168.123.11   ip-172-31-17-15   <none>           <none>
    taint-deployment-6bbd58d65d-5wk69   1/1     Running   0          2m30s   192.168.123.14   ip-172-31-17-15   <none>           <none>
    taint-deployment-6bbd58d65d-9qt9b   1/1     Running   0          2m30s   192.168.123.10   ip-172-31-17-15   <none>           <none>
    taint-deployment-6bbd58d65d-j5r4j   1/1     Running   0          2m30s   192.168.123.12   ip-172-31-17-15   <none>           <none>
    taint-deployment-6bbd58d65d-q8h98   1/1     Running   0          2m30s   192.168.123.13   ip-172-31-17-15   <none>           <none>
    taint-deployment-6bbd58d65d-vlwtk   1/1     Running   0          2m30s   192.168.123.17   ip-172-31-17-15   <none>           <none>
    taint-deployment-6bbd58d65d-wm66g   1/1     Running   0          2m30s   192.168.123.16   ip-172-31-17-15   <none>           <none>


You can see that all the pods are scheduled on the node without the taint `bubba=value:PreferNoSchedule`.

Now let's remove the taint from the nodes and see how the scheduler schedules the pods.

.. code-block:: bash

    kubectl taint nodes ip-172-31-29-155 ip-172-31-31-226 bubba=value:PreferNoSchedule-

    node/ip-172-31-29-155 untainted
    node/ip-172-31-31-226 untainted

You can see that the pods are still scheduled on the node without the taint.

.. code-block:: bash

    kubectl get pods -l app=nginx -o wide

    NAME                                READY   STATUS    RESTARTS   AGE   IP               NODE              NOMINATED NODE   READINESS GATES
    taint-deployment-6bbd58d65d-2nw48   1/1     Running   0          11m   192.168.123.15   ip-172-31-17-15   <none>           <none>
    taint-deployment-6bbd58d65d-4lll6   1/1     Running   0          11m   192.168.123.11   ip-172-31-17-15   <none>           <none>
    taint-deployment-6bbd58d65d-5wk69   1/1     Running   0          11m   192.168.123.14   ip-172-31-17-15   <none>           <none>
    taint-deployment-6bbd58d65d-9qt9b   1/1     Running   0          11m   192.168.123.10   ip-172-31-17-15   <none>           <none>
    taint-deployment-6bbd58d65d-j5r4j   1/1     Running   0          11m   192.168.123.12   ip-172-31-17-15   <none>           <none>
    taint-deployment-6bbd58d65d-q8h98   1/1     Running   0          11m   192.168.123.13   ip-172-31-17-15   <none>           <none>
    taint-deployment-6bbd58d65d-vlwtk   1/1     Running   0          11m   192.168.123.17   ip-172-31-17-15   <none>           <none>
    taint-deployment-6bbd58d65d-wm66g   1/1     Running   0          11m   192.168.123.16   ip-172-31-17-15   <none>           <none>



Now let's taint the node which has the dele the deployment and create it again to see how the scheduler schedules the pods.

.. code-block:: bash

    kubectl delete deployment taint-deployment

    deployment.apps "taint-deployment" deleted from default namespace

.. code-block:: bash

    kubectl create -f taint.yaml 

    deployment.apps/taint-deployment created

.. code-block:: bash

    kubectl get pods -l app=nginx -o wide | grep Running
    taint-deployment-6bbd58d65d-58fqv   1/1     Running     0          54s   192.168.123.18    ip-172-31-17-15    <none>           <none>
    taint-deployment-6bbd58d65d-6hcvj   1/1     Running     0          54s   192.168.244.58    ip-172-31-29-155   <none>           <none>
    taint-deployment-6bbd58d65d-fpvvx   1/1     Running     0          54s   192.168.244.60    ip-172-31-29-155   <none>           <none>
    taint-deployment-6bbd58d65d-h7rfg   1/1     Running     0          54s   192.168.244.59    ip-172-31-29-155   <none>           <none>
    taint-deployment-6bbd58d65d-mc462   1/1     Running     0          54s   192.168.123.19    ip-172-31-17-15    <none>           <none>
    taint-deployment-6bbd58d65d-mlzrf   1/1     Running     0          39s   192.168.123.20    ip-172-31-17-15    <none>           <none>
    taint-deployment-6bbd58d65d-sk58r   1/1     Running     0          54s   192.168.214.181   ip-172-31-31-226   <none>           <none>
    taint-deployment-6bbd58d65d-t9qfn   1/1     Running     0          54s   192.168.214.183   ip-172-31-31-226   <none>           <none>


Now you can see that the pods are scheduled across all nodes.

Now let's taint one of the worker nodes with the taint `bubba=value:NoExecute` and see how the scheduler schedules the pods.

.. code-block:: bash

    kubectl taint nodes ip-172-31-29-155 bubba=value:NoExecute

    node/ip-172-31-29-155 tainted

You can see that the pods that are scheduled on the node with the taint `bubba=value:NoExecute` are evicted and the new pods are not scheduled on 
that node.

.. code-block:: bash


    kubectl get pods -l app=nginx -o wide | grep Running

    taint-deployment-6bbd58d65d-2bd89   1/1     Running     0          43s     192.168.123.21    ip-172-31-17-15    <none>           <none>
    taint-deployment-6bbd58d65d-58fqv   1/1     Running     0          4m56s   192.168.123.18    ip-172-31-17-15    <none>           <none>
    taint-deployment-6bbd58d65d-78mhj   1/1     Running     0          43s     192.168.123.22    ip-172-31-17-15    <none>           <none>
    taint-deployment-6bbd58d65d-mc462   1/1     Running     0          4m56s   192.168.123.19    ip-172-31-17-15    <none>           <none>
    taint-deployment-6bbd58d65d-mlzrf   1/1     Running     0          4m41s   192.168.123.20    ip-172-31-17-15    <none>           <none>
    taint-deployment-6bbd58d65d-sk58r   1/1     Running     0          4m56s   192.168.214.181   ip-172-31-31-226   <none>           <none>
    taint-deployment-6bbd58d65d-t9qfn   1/1     Running     0          4m56s   192.168.214.183   ip-172-31-31-226   <none>           <none>
    taint-deployment-6bbd58d65d-w8lhw   1/1     Running     0          42s     192.168.123.23    ip-172-31-17-15    <none>           <none>