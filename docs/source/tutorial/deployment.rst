Deployment
====================

A Deployment is a controller object in Kubernetes that continuously monitors and maintains the desired state of an application. It provides
declarative management of Pods and ReplicaSets, ensuring that the specified number of Pod replicas are running at all times,
even if multiple Pods are scheduled on the same node. A Deployment is a high-level resource used to manage the rollout, scaling,
and updating of containerised applications. It defines the desired application state, including the container image, replica count, and
update strategy. When a Deployment is created, Kubernetes automatically creates and manages the required ReplicaSets, which in turn
create and manage the Pods needed to satisfy the desired state. Deployments also support rolling updates, allowing applications to be
upgraded gradually without downtime by replacing old Pods with new ones incrementally. This makes Deployments a reliable and scalable
way to manage containerised workloads in Kubernetes.



.. code-block:: bash

    kubectl create deploy webserver --image nginx:1.22.1 --replicas=2 --dry-run=client -o yaml | tee dep.yaml

.. note::

    The `--dry-run=client` flag generates the Kubernetes resource locally without creating it in the cluster.

.. code-block:: bash

    kubectl create -f dep.yaml

    deployment.apps/webserver created


.. code-block:: bash


    kubectl get deploy

    NAME        READY   UP-TO-DATE   AVAILABLE   AGE
    webserver   2/2     2            2           46s


.. code-block:: bash

    NAME                        READY   STATUS    RESTARTS   AGE
    webserver-f4488cc5d-gnn4x   1/1     Running   0          3m14s
    webserver-f4488cc5d-ss7w5   1/1     Running   0          3m14s


.. code-block:: bash

    kubectl describe pod webserver-f4488cc5d-gnn4x | grep Image:
    Image:          nginx:1.22.1

Rollout and Rollback
----------------------

One of the key advantages of microservices is the ability to replace or upgrade containers while still serving client requests. In this exercise,
we will first use the `Recreate` deployment strategy, where existing containers are terminated before new ones are started. We will then explore
the `RollingUpdate` strategy, which performs updates gradually by replacing old containers with new ones incrementally, allowing the application
to remain available during the update process.

.. code-block:: bash

    kubectl get deploy webserver -o yaml | grep -A 4 strategy

    strategy:
      rollingUpdate:
        maxSurge: 25%
        maxUnavailable: 25%
      type: RollingUpdate


Edit the deployment to use the `Recreate` strategy with the following command:


.. code-block:: bash

    kubectl edit deploy webserver

.. code-block:: yaml

    strategy:
      rollingUpdate:  # <-- remove this line
        maxSurge: 25%  # <-- remove this line
        maxUnavailable: 25%  # <-- remove this line
      type: Recreate  # <-- edit this line


.. note::

    The `Recreate` strategy will cause downtime during the update process, as all existing Pods will
    be terminated before new ones are started. This can be useful for applications that cannot run
    multiple versions simultaneously or have stateful components that require a clean shutdown.

Now also change the image of the deployment.

.. code-block:: bash

    kubectl set image deploy webserver nginx=nginx:1.23.1-alpine

.. note::

    `nginx` is the container name and `nginx:1.23.1-alpine` is the new image in the command:
    `kubectl set image deploy webserver nginx=nginx:1.23.1-alpine`

    These details are available using the `get` command.




.. code-block:: bash

    kubectl get pods

    NAME                         READY   STATUS    RESTARTS   AGE
    webserver-6884794fb9-p7m79   1/1     Running   0          39s
    webserver-6884794fb9-pwj9b   1/1     Running   0          39s


.. code-block:: bash

    kubectl describe po | grep Image:
    Image:          nginx:1.23.1-alpine
    Image:          nginx:1.23.1-alpine



Now we can see the history of the deployment rollouts:

.. code-block:: bash

    kubectl rollout history deploy webserver

    deployment.apps/webserver
    REVISION  CHANGE-CAUSE
    1         <none>
    2         kubectl set image deploy webserver nginx=nginx:1.23.1-alpine


The above results show that there have been 2 revisions of the deployment, with the second revision being the result of the image update.
We can also see the details of each revision.

.. code-block:: bash

    kubectl rollout history deploy webserver --revision=1

    deployment.apps/webserver with revision #1
    Pod Template:
      Labels:       app=webserver
            pod-template-hash=f4488cc5d
      Containers:
       nginx:
        Image:      nginx:1.22.1
        Port:       <none>
        Host Port:  <none>
        Environment:        <none>
        Mounts:     <none>
      Volumes:      <none>
      Node-Selectors:       <none>
      Tolerations:  <none>

.. code-block:: bash

    kubectl rollout history deploy webserver --revision=2

    deployment.apps/webserver with revision #2
    Pod Template:
      Labels:       app=webserver
            pod-template-hash=6884794fb9
      Annotations:  kubernetes.io/change-cause: kubectl set image deploy webserver nginx=nginx:1.23.1-alpine
      Containers:
       nginx:
        Image:      nginx:1.23.1-alpine
        Port:       <none>
        Host Port:  <none>
        Environment:        <none>
        Mounts:     <none>
      Volumes:      <none>
      Node-Selectors:       <none>
      Tolerations:  <none>


The above results show the details of each revision, including the image used in each revision.
We can see that the first revision used the `nginx:1.22.1` image, while the second revision used
the `nginx:1.23.1-alpine` image.


Now we can undo the last rollout and revert the deployment back to the previous revision.

.. code-block:: bash

    kubectl rollout undo deploy webserver

.. code-block:: bash

    kubectl get pods

    NAME                        READY   STATUS    RESTARTS   AGE
    webserver-f4488cc5d-hlfr5   1/1     Running   0          25s
    webserver-f4488cc5d-jhv9m   1/1     Running   0          25s

.. note::

    You can also specify the revision to undo to, for example
    `kubectl rollout undo deploy webserver --to-revision=1`
    to revert back to the first revision.