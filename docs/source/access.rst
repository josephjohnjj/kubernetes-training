Outside Access
==================

Getting access to the cluster is an important part of working with Kubernetes. This section covers how to access the cluster and its resources.

First get the list of pods in the cluster. This will show you the basic information about the pods, including their names, status, and the nodes they are running on.

.. code-block:: bash

    kubectl get po 

or

.. code-block:: bash

    kubectl get po -o wide

The ``-o wide`` option provides additional information such as the node name and IP address of each pod, which can be helpful for troubleshooting 
and understanding the cluster's layout. A sample output might look like this:


.. code-block:: bash

    NAME                     READY   STATUS    RESTARTS   AGE   IP               NODE               NOMINATED NODE   READINESS GATES
    nginx-7ccccd94f7-4r2w7   1/1     Running   0          4d    192.168.244.12   ip-172-31-29-155   <none>           <none>
    nginx-7ccccd94f7-ndhph   1/1     Running   0          4d    192.168.244.11   ip-172-31-29-155   <none>           <none>
    nginx-7ccccd94f7-pftwd   1/1     Running   0          4d    192.168.244.10   ip-172-31-29-155   <none>           <none>


`printenv` is a standard Linux command that prints all environment variables available in the current shell. When you run `kubectl exec` to execute a 
command inside a container, you can use `printenv` to see the environment variables that are set for that container. This can be useful for debugging and
understanding the configuration of the application running inside the container. 

.. code-block:: bash

    kubectl exec nginx-7ccccd94f7-4r2w7 -- printenv | grep KUBERNETES

This command will print all environment variables that contain the string "KUBERNETES"

.. code-block:: bash

    KUBERNETES_PORT_443_TCP_ADDR=10.96.0.1
    KUBERNETES_PORT=tcp://10.96.0.1:443
    KUBERNETES_PORT_443_TCP=tcp://10.96.0.1:443
    KUBERNETES_PORT_443_TCP_PROTO=tcp
    KUBERNETES_SERVICE_HOST=10.96.0.1
    KUBERNETES_SERVICE_PORT=443
    KUBERNETES_PORT_443_TCP_PORT=443
    KUBERNETES_SERVICE_PORT_HTTPS=443


Find all the running services in the cluster. This will show you the services that are currently running, along with their types, cluster IPs, and ports.

.. code-block:: bash

    kubectl get svc

then delete the existing service for nginx.

.. code-block:: bash

    kubectl delete svc nginx


Create the service again using the `LoadBalancer` type. 


.. code-block:: bash

    kubectl expose deployment nginx --type=LoadBalancer
    


.. note::

    Pods created by a Deployment are temporary and can be replaced at any time. Their IP addresses can change when pods restart, scale, or 
    move to another node.If users connected directly to pod IPs, access would break often.

    A Service solves this by giving the application:

    1. one stable name

    2. one stable virtual IP

    3. automatic traffic distribution to healthy pods

    So instead of exposing pods individually, Kubernetes exposes the Service.

.. note::
    
    Services can be exposed in different ways by specifying a type in the ServiceSpec.

    1. ClusterIP (default): Accessible only inside the cluster.

    2. NodePort: Accessible from outside the cluster by opening a specific port on all nodes.
    
    3. LoadBalancer: Best for public access. Kubernetes asks the cloud provider to create an external load balancer.

    
    - Amazon Web Services Elastic Load Balancer
    - Google Cloud Cloud Load Balancer
    - Microsoft Azure Azure Load Balancer

    These load balancer forwards traffic into the cluster.


Check to see the status and note the external ports mentioned. 

.. code-block:: bash

    kubectl get svc

    
    NAME         TYPE           CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
    kubernetes   ClusterIP      10.96.0.1       <none>        443/TCP        70d
    nginx        LoadBalancer   10.106.109.72   <pending>     80:31789/TCP   76s

.. note::

    port 80:  The Service port (what Kubernetes exposes internally)
    port 31789: The NodePort (what is actually opened on each EC2 node)




The output will show the External-IP as pending. Unless a provider responds with a load balancer it will
continue to show as pending.

Here the port 80 is mapped to a random port on the node (31789 in this case). You can access the nginx service by sending a request to the node's IP 
address and the mapped port. For example, if the node's IP address is 4.89.209.24 and the mapped port is 31789, you can access the nginx service by
going to http://4.89.209.243:31789 in your web browser or using a tool like `curl`:

.. code-block:: bash

    curl http://4.89.209.243:31789


Now scale the deployment to 0 replicas and check the service again.

.. code-block:: bash

    kubectl scale deployment nginx --replicas=0

    kubectl get po

Now scale the deployment to 2 replicas

.. code-block:: bash

    kubectl scale deployment nginx --replicas=2

    kubectl get po


and check the service again from the local node. 

.. code-block:: bash

    curl http://4.89.209.243:31789


Finally, delete the deployment and service.

.. code-block:: bash

    kubectl delete deployment nginx

    kubectl delete svc nginx

    

