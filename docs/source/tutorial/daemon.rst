Daemon Set
=============


A DaemonSet is a Kubernetes controller object, similar to a Deployment, that continuously monitors 
the cluster and ensures that a specific Pod runs on selected nodes. Unlike a Deployment, which only 
guarantees a desired number of Pod replicas across the cluster, a DaemonSet ensures that each eligible 
node runs exactly one instance of the Pod. When a new node joins the cluster, the DaemonSet 
automatically creates the required Pod on that node. Likewise, when a node is removed, the associated 
Pods are automatically cleaned up.

DaemonSets are commonly used for system-level services that should run on every node, such as logging 
agents, monitoring tools, networking components, and storage services. This is particularly useful in 
large or dynamic clusters where nodes may frequently be added, removed, or replaced. Since Kubernetes 
v1.12, the scheduler has managed DaemonSet Pod placement, allowing administrators to control 
which nodes should or should not run specific DaemonSet Pods through labels, taints, and tolerations.

DaemonSets are also valuable in complex infrastructure environments, such as distributed storage 
systems like Ceph, where storage resources may only exist on particular hardware. Combined with 
resource requests, limits, node selectors, and volume configurations, DaemonSets enable flexible 
and automated deployment of node-specific services across a cluster.


We can create a DaemonSet using the following YAML definition, `ds.yaml`:

.. code-block:: yaml

    apiVersion: apps/v1
    kind: DaemonSet

    metadata:
      name: ds-one

    spec:

      selector:
        matchLabels:
          system: DaemonSetOne

      template:
        metadata:
          labels:
            system: DaemonSetOne

        spec:
          containers:
          - name: nginx
            image: nginx:1.22.1



.. code-block:: bash

    kubectl get ds

    NAME     DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE   NODE SELECTOR   AGE
    ds-one   2         2         2       2            2           <none>          10s

.. note::

   
    I have 2 worker nodes in my cluster, so the DaemonSet created 2 Pods, one on each worker node. The `NODE SELECTOR` column is `<none>` 
    because we did not specify any node selectors in our DaemonSet definition, which means that the DaemonSet will run on all eligible nodes 
    in the cluster. If we had specified a node selector, it would have shown the criteria used to select nodes for running the DaemonSet Pods.


.. code-block:: bash

    kubectl get pods

    NAME           READY   STATUS    RESTARTS   AGE
    ds-one-cj9jf   1/1     Running   0          2m10s
    ds-one-qdlcn   1/1     Running   0          2m10s


Similar to `Deployments`, we can also update the `DaemonSet` using rollout and rollback.


.. code-block:: bash

    kubectl get ds ds-one -o yaml | grep -A 4 Strategy

    updateStrategy:
      rollingUpdate:
        maxSurge: 0
        maxUnavailable: 1
      type: RollingUpdate


Now ltes change th typw to `OnDelete` and apply the change:

.. code-block:: yaml

    updateStrategy:
      rollingUpdate:
        maxSurge: 0
        maxUnavailable: 1
      type: OnDelete

.. note::
    
    The `OnDelete` update strategy will not automatically update the Pods when the DaemonSet definition is changed. Instead, it will wait 
    until the existing Pods are manually deleted before creating new ones with the updated configuration. This can be useful for 
    applications that require manual intervention during updates or have stateful components that need to be gracefully shut 
    down before being replaced.



.. code-block:: bash

    kubectl edit ds ds-one


Now chnage the image to `nginx:1.23.1` and save the change.


.. code-block:: bash

   kubectl set image ds ds-one nginx=nginx:1.23.1-alpine


Now let delete one of the Pods to trigger the update:

.. code-block:: bash

    kubectl get pods

    kubectl get pods

    NAME           READY   STATUS    RESTARTS   AGE
    ds-one-cj9jf   1/1     Running   0          28m
    ds-one-qdlcn   1/1     Running   0          28m

.. code-block:: bash
    
    kubectl delete pod ds-one-cj9jf

    kubectl get pods

    NAME           READY   STATUS    RESTARTS   AGE
    ds-one-bns72   1/1     Running   0          16s
    ds-one-qdlcn   1/1     Running   0          29m


You can see that the deleted Pod `ds-one-cj9jf` has been replaced with a new Pod `ds-one-bns72` that is running the updated image.

You can also check the imgae in both th existing pods to verify that the update has been applied:

.. code-block:: bash

    kubectl describe po ds-one-qdlcn  | grep Image:

    Image:          nginx:1.22.1

.. code-block:: bash

    kubectl describe po ds-one-bns72 | grep Image:

    Image:          nginx:1.23.1-alpine

The older pod uses the older image `nginx:1.22.1`, while the new pod uses the updated image `nginx:1.23.1-alpine`, confirming that the update has
been successfully applied to the new Pod created after the deletion of the old one.


If you checkout the rollout history of the DaemonSet, you will get


.. code-block:: bash

    kubectl rollout history ds ds-one\

    daemonset.apps/ds-one 
    REVISION  CHANGE-CAUSE
    1         <none>
    2         <none>

This is beacuse we didnt use --record flag when we updated the DaemonSet, so there is no change cause recorded for the update.
The record flag is deprecated in newer versions of kubectl, so you can use the `--change-cause` flag to specify a change cause when updating 
the DaemonSet. For example:

.. code-block:: bash

    kubectl annotate ds ds-one kubernetes.io/change-cause="Upgrade nginx"

    kubectl set image ds ds-one nginx=nginx:1.24


Now if you check the rollout history again, you will see the change cause for the update:

.. code-block:: bash

    kubectl rollout history ds ds-one

    daemonset.apps/ds-one 
    REVISION  CHANGE-CAUSE
    1         <none>
    2         <none>
    3         Updated nginx to 1.23.1-alpine


if you use RollingUpdate strategy, the update will be applied automatically to all the Pods without needing to delete them manually.
You can also check the status of the rollout using the `rollout status` command:

.. code-block:: bash

    kubectl rollout status ds ds-one

    daemonset "ds-one" successfully rolled out


.. code-block:: bash

    kubectl delete ds ds-one
    
    daemonset.apps "ds-one" deleted from default namespace