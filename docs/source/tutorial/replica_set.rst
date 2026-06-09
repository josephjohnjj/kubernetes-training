Replica Sets
================

Replica Sets are a Kubernetes resource that ensures a specified number of pod replicas are running at any given time. 
They are used to maintain the desired state of the application and provide high availability.

.. code-block:: bash

    kubectl get rs


.. code-block:: yaml

    apiVersion: apps/v1
    kind: ReplicaSet

    metadata:
      name: rs-one

    spec:
      replicas: 2

      selector:
        matchLabels:
          system: ReplicaOne

      template:
        metadata:
          labels:
            system: ReplicaOne

        spec:
          containers:
          - name: nginx
            image: nginx:1.22.1


Apply the ReplicaSet definition:

.. code-block:: bash

    kubectl apply -f rs.yml

Check the status of the ReplicaSet:

.. code-block:: bash

    kubectl get rs

    NAME     DESIRED   CURRENT   READY   AGE
    rs-one   2         2         2       30s


Describe the ReplicaSet to see more details:

.. code-block:: bash

    kubectl describe rs rs-one

    Name:         rs-one
    Namespace:    default
    Selector:     system=ReplicaOne
    Labels:       <none>
    Annotations:  <none>
    Replicas:     2 current / 2 desired
    Pods Status:  2 Running / 0 Waiting / 0 Succeeded / 0 Failed
    Pod Template:
      Labels:  system=ReplicaOne
      Containers:
       nginx:
        Image:         nginx:1.22.1
        Port:          <none>
        Host Port:     <none>
        Environment:   <none>
        Mounts:        <none>
      Volumes:         <none>
      Node-Selectors:  <none>
      Tolerations:     <none>
    Events:
      Type    Reason            Age   From                   Message
      ----    ------            ----  ----                   -------
      Normal  SuccessfulCreate  90s   replicaset-controller  Created pod: rs-one-9hsmn
      Normal  SuccessfulCreate  90s   replicaset-controller  Created pod: rs-one-chm4f


Now find the pods that were created by the ReplicaSet:

.. code-block:: bash

    kubectl get pods

    NAME           READY   STATUS    RESTARTS   AGE
    rs-one-9hsmn   1/1     Running   0          73m
    rs-one-chm4f   1/1     Running   0          73m


The `--cascade=orphan` flag allows you to delete the ReplicaSet without deleting the pods that it created. 
This can be useful if you want to keep the pods running but remove the ReplicaSet that manages them. 


.. code-block:: bash

    kubectl delete rs rs-one --cascade=orphan

    kubectl get rs

    No resources found in default namespace.


You can see that the ReplicaSet has been deleted, but the pods are still running:

.. code-block:: bash

    kubectl get pods

    NAME           READY   STATUS    RESTARTS   AGE
    rs-one-9hsmn   1/1     Running   0          78m
    rs-one-chm4f   1/1     Running   0          78m

Recreate the ReplicaSet. Provided the `selector` field remains unchanged, the new ReplicaSet should adopt the existing Pods. However, 
this method cannot be used to update the software version running inside the Pods.


.. code-block:: bash

    kubectl apply -f rs.yaml


.. code-block:: bash

    kubectl get rs

    NAME     DESIRED   CURRENT   READY   AGE
    rs-one   2         2         2       11s



.. code-block:: bash

    kubectl get pods

    NAME           READY   STATUS    RESTARTS   AGE
    rs-one-9hsmn   1/1     Running   0          85m
    rs-one-chm4f   1/1     Running   0          85m

Now edit pod to isolate it from the ReplicaSet by changing the label that the ReplicaSet uses to select its pods:

.. code-block:: bash

    kubectl edit pod rs-one-9hsmn 

You will see the pod definition in your default editor. Change the label from `system: ReplicaOne` to `system: IsolatePod` and save the file.

.. code-block:: yaml

    labels:
        system: IsolatePod
      name: rs-one-9hsmn


Now check the status of the ReplicaSet again:

.. code-block:: bash

    kubectl get rs

    NAME     DESIRED   CURRENT   READY   AGE
    rs-one   2         2         2       6m41s


You can see that the ReplicaSet has created a new pod to replace the one that was isolated. 


.. code-block:: bash

     kubectl get pods
    NAME           READY   STATUS    RESTARTS   AGE
    rs-one-9hsmn   1/1     Running   0          90m
    rs-one-chm4f   1/1     Running   0          90m
    rs-one-wp9pb   1/1     Running   0          112s


At the same time, the isolated pod is still running but it is no longer managed by the ReplicaSet.

.. code-block:: bash

    kubectl get po -L system

    NAME           READY   STATUS    RESTARTS   AGE     SYSTEM
    rs-one-9hsmn   1/1     Running   0          91m     IsolatePod
    rs-one-chm4f   1/1     Running   0          91m     ReplicaOne
    rs-one-wp9pb   1/1     Running   0          3m19s   ReplicaOne


The `-L` flag allows you to display the value of a specific label in the output. In this case, we are displaying the value of the `system` label for 
each pod.


Now delete the ReplicaSet again and then the isolated pods as well.

.. code-block:: bash

    kubectl get po 
    NAME           READY   STATUS    RESTARTS   AGE
    rs-one-9hsmn   1/1     Running   0          93m


.. code-block:: bash

    kubectl get po 
    NAME           READY   STATUS    RESTARTS   AGE
    rs-one-9hsmn   1/1     Running   0          93m


.. code-block:: bash

    kubectl delete pod -l system=IsolatePod

    pod "rs-one-9hsmn" deleted from default namespace


`-l` flag allows you to delete pods based on their labels. In this case, we are deleting all pods that have the label `system=IsolatePod`.

.. note::

    In Kubernetes, `-l` and `-L` are different command-line options related to labels. The lowercase `-l` is a label selector used to filter resources 
    based on label values, such as `kubectl get pods -l app=web`, which only returns Pods with the label `app=web`. In contrast, the uppercase 
    `-L` displays label values as additional columns in the command output, such as `kubectl get pods -L app`, which shows the `app` label for
    all Pods without filtering them.
