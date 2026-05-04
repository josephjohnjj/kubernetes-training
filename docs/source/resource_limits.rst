Resource Limits
===================================

Launch a deployment with the `vish/stress` image, which is a simple container that can be used to generate CPU and memory load. 
This will allow us to see how resource limits work in Kubernetes.


.. code-block:: bash

    kubectl create deployment hog --image vish/stress

    kubectl get deployments

    kubectl describe deployment hog

    kubectl get deployment hog -o yaml

    kubectl get deployment hog -o yaml > hog.yaml


Now, let's edit the deployment to add resource limits.  Open the `hog.yaml` file in your favorite text editor you can see the `resources` field is 
currently empty. We will add limits for CPU and memory.

.. code-block:: yaml

    containers:
          - image: vish/stress
            imagePullPolicy: Always
            name: stress
            resources: {}
            terminationMessagePath: /dev/termination-log
            terminationMessagePolicy: File
          dnsPolicy: ClusterFirst
          restartPolicy: Always
          schedulerName: default-scheduler
          securityContext: {}
          terminationGracePeriodSeconds: 30


Change the `resources` field to look like this:
.. code-block:: yaml

    containers:
          - image: vish/stress
            imagePullPolicy: Always
            name: stress
            resources:
                limits:
                    memory: "4Gi"
                requests:
                    memory: "2500Mi"
            terminationMessagePath: /dev/termination-log
            terminationMessagePolicy: File
          dnsPolicy: ClusterFirst
          restartPolicy: Always
          schedulerName: default-scheduler
          securityContext: {}
          terminationGracePeriodSeconds: 30
          

In Kubernetes, requests and limits define how much resource a container is guaranteed versus the maximum it is allowed to use.

* Request = 2500Mi

    - Kubernetes guarantees the container at least 2500 MiB (~2.44 GiB) of memory.

    - The scheduler uses this value when deciding which node can run the pod.

    - A node must have at least this much allocatable memory available before the pod can be scheduled there.


* Limit = 4Gi

    - The container is allowed to use up to 4 GiB of memory.

    - If the container exceeds this limit, Kubernetes/OOM killer may terminate the container.

Now replace the existing deployment with the updated YAML file:
.. code-block:: bash

    kubectl apply -f hog.yaml

    kubectl describe deployment hog

    kubectl get deployment hog -o yaml


Lest find the details of the pod that is running the container:

.. code-block:: bash

    kubectl get pods

    NAME                   READY   STATUS    RESTARTS   AGE
    hog-8696ccdcc4-jn78s   1/1     Running   0          92s
 

.. code-block:: bash

    kubectl describe podhog-8696ccdcc4-jn78s

    kubectl logs hog-8696ccdcc4-jn78s

    I0504 00:52:43.293541       1 main.go:26] Allocating "0" memory, in "4Ki" chunks, with a 1ms sleep between allocations
    I0504 00:52:43.293637       1 main.go:29] Allocated "0" memory



You can use the `top`` command to see the resource usage of the pod in the worker nodes.

First finsd the node that is running the pod:


.. code-block:: bash

    kubectl get pods -o wide

    NAME                   READY   STATUS    RESTARTS   AGE    IP               NODE               NOMINATED NODE   READINESS GATES
    hog-8696ccdcc4-jn78s   1/1     Running   0          3h5m   192.168.244.24   ip-172-31-29-155   <none>           <none>

Now login to the node `ip-172-31-29-155` and run the `top` command to see the resource usage of the pod:

.. code-block:: bash

    
        PID USER      PR  NI    VIRT    RES    SHR S  %CPU  %MEM     TIME+ COMMAND                                                                                                         
      62116 root      20   0 2235640  76512  51636 S   1.0   0.9     23,47 calico-node                                                                                                     
    1251962 root      20   0 2028688  86060  52360 S   1.0   1.1  39:36.71 kubelet                                                                                                         
      59569 root      20   0 2019340  81816  38940 S   0.3   1.0      9,14 containerd                                                                                                      
    1256564 root      20   0 1233840  11488   7480 S   0.3   0.1   0:43.08 containerd-shim


Here you can see the `kubelet` process is using 1.1% of memory, which is around 86060 KiB. This is because the `kubelet` is responsible for 
managing the pods and containers on the node, and it is using some memory to manage the `hog` pod. The `calico-node` process is also using some memory, 
which is expected as it is responsible for networking in the cluster. The `containerd` and `containerd-shim` processes are also using some memory, 
which is expected as they are responsible for running the containers on the node.


Now lets change the resource limits againto see how it affects the pod. Edit the `hog.yaml` file and change the limits to:


.. code-block:: yaml

    containers:
          - image: vish/stress
            imagePullPolicy: Always
            name: stress
            resources:
                limits:
                    cpu: "2"
                    memory: "4Gi"
                requests:
                    cpu: "1"
                    memory: "1Gi"
            terminationMessagePath: /dev/termination-log
            terminationMessagePolicy: File
          dnsPolicy: ClusterFirst
          restartPolicy: Always
          schedulerName: default-scheduler
          securityContext: {}
          terminationGracePeriodSeconds: 30


Then  lets  delete the existing deployment and create a new one with the updated YAML file:

.. code-block:: bash

    kubectl delete deployment hog

    kubectl apply -f hog.yaml

    kubectl describe deployment hog

    kubectl get deployment hog -o yaml


Now if we check the top command again on the node, we should see that the `kubelet` process is using more CPU and memory, as it is now managing a pod 
with higher resource limits.

.. code-block:: bash

    PID USER      PR  NI    VIRT    RES    SHR S  %CPU  %MEM     TIME+ COMMAND                                                                                                         
  62596 root      20   0 2161908  76636  51764 S   1.0   0.9     19,16 calico-node                                                                                                     
 132772 root      20   0 2028432  83296  52036 S   0.7   1.0  36:29.45 kubelet                                                                                                         
  60065 root      20   0 2149068  75676  36760 S   0.3   0.9     12,01 containerd                                                                                                      
  62120 root      20   0 1369104 163136   7824 S   0.3   2.0     13,41 containerd-shim   


When you increae the usage and if there are errors you can find the details in the pods

.. code-block:: bash

    kubectl get pods -o wide

    NAME                   READY   STATUS    RESTARTS   AGE    
    hog-8696ccdcc4-jn78s   1/1     Running   0          5s

The you can look at the logs of the pod to see if there are any errors, for example if the pod is using more memory than the limit, 
it will be terminated by the OOM killer and you can see the details in the logs:

.. code-block:: bash

    kubectl logs hog-8696ccdcc4-jn78s

    "goroutine 1 [running]:
    panic(0x5ff9a0, 0xc820014cb0)
    /usr/local/go/src/runtime/panic.go:481 +0x3e6 k8s.io/kubernetes/pkg/api/resource.MustParse(0x7ffe460c0e69, 0x5, 0x0, 0x0, 0x0,
    <→  0x0, 0x0)
    /usr/local/google/home/vishnuk/go/src/k8s.io/kubernetes/pkg/api/resource/quanti
    <→  +0x287
    main.main()
    /usr/local/google/home/vishnuk/go/src/github.com/vishh/stress/main.go:24 +0x43"

