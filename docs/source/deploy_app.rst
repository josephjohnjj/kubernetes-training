Deploy an application
==================

Create a new deployment, which is a Kubernetes object, which will deploy an application in a 
container. Verify it is running and the desired number of containers matches the available.

.. code-block:: bash

    
    kubectl create deployment nginx --image=nginx

    kubectl get deployments


View the details of the deployment. 

.. code-block:: bash

    
    kubectl describe deployment nginx 


or

.. code-block:: bash

    kubectl get deployment nginx -o yaml

    kubectl get deployment nginx -o yaml > first.yaml

View the basic steps the cluster took in order to pull and deploy the new application.


.. code-block:: bash

    kubectl get events

Delete the deployment

.. code-block:: bash

    kubectl delete deployment nginx

Create from yaml file

.. code-block:: bash

    kubectl apply -f first.yaml


`--dry-run=client` generates the Kubernetes resource locally without creating it in the cluster.
It does not contact the API server or persist anything.


.. code-block:: bash

    kubectl create deployment two --image=nginx --dry-run=client -o yaml

This is especially useful when you want to generate a manifest file for a resource without actually 
creating it in the cluster.


After creating a Service, it must be exposed so it can accept network traffic.
Create a Service in front of an existing workload to enable it to receive network traffic.

.. code-block:: bash

    kubectl expose deployment/nginx

    error: couldn't find port via --port flag or introspection

So we need to change the oject configuration/definition to include the port number. 
To change an object definition we can use the commands `edit`, `patch` or `apply`.


To expose the deployment add this to the deployment definition (`first.yaml`):

.. code-block:: bash

    containers:
          - image: nginx
            imagePullPolicy: Always
            name: nginx
            ports:                    # To be added
             - containerPort: 80      # To be added
               protocol: TCP          # To be added

Then apply the changes to the cluster:

.. code-block:: bash

     kubectl replace -f first.yaml --force


     kubectl get deploy,pod


Then expose the deployment again:

.. code-block:: bash

    kubectl expose deployment/nginx

Now the service is created and exposed, we can check the service details:

.. code-block:: bash

    kubectl get svc nginx

We can also check the endpoints of the service to verify that it is correctly routing to the pods:

.. code-block:: bash

    kubectl get ep nginx


Now we have a deployment with 1 replica and a service exposing it. We can scale the deployment to 
have more replicas:

.. code-block:: bash

    kubectl scale deployment nginx --replicas=3

    kubectl get deployments

    kubectl get pods

Now check the endpoints again to see that the service is routing to all the pods:

.. code-block:: bash

    kubectl get ep nginx

Get the logs of one of the pods:

.. code-block:: bash

    kubectl get pods -o wide

Now even if we delete one of the pods, the deployment will automatically create a new one to 
maintain the desired number of replicas:

.. code-block:: bash

    kubectl delete pod nginx-xxxx-xxxx

    kubectl get pods -o wide

