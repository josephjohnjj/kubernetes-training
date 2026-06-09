Labels
========

Delete all Pods with the `system=secondary` label in all namespaces.

.. code-block:: bash

    kubectl delete pods -l system=secondary --all-namespaces

    pod "nginx-one-79bb9b75fd-jltvg" deleted from accounting namespace
    pod "nginx-one-79bb9b75fd-js482" deleted from accounting namespace
    pod "nginx-one-79bb9b75fd-knjqh" deleted from accounting namespace
    pod "nginx-one-79bb9b75fd-vq87z" deleted from accounting namespace


New versions of the Pods should be running as the controller responsible for them continues.

.. code-block:: bash

    kubectl -n accounting get pods

    NAME                         READY   STATUS    RESTARTS   AGE
    nginx-one-79bb9b75fd-ktfxs   1/1     Running   0          1m
    nginx-one-79bb9b75fd-xk8vg   1/1     Running   0          1m


.. code-block:: bash

    kubectl -n accounting get deploy --show-labels

    NAME        READY   UP-TO-DATE   AVAILABLE   AGE   LABELS
    nginx-one   2/2     2            2           47h   system=secondary


Delete the deployment using its label:

.. code-block:: bash

    kubectl -n accounting delete deploy -l system=secondary

    deployment.apps "nginx-one" deleted from accounting namespace