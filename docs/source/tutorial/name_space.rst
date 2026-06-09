Resource Limit for a Namespace
==============================

Create a namespace called `low-usage-limit`.

.. code-block:: bash

    kubectl create namespace low-usage-limit


Create a YAML file called `low-usage-limit.yaml` with the following content:

.. code-block:: yaml

    apiVersion: v1
    kind: LimitRange
    metadata:
      name: low-resource-range
    spec:
      limits:
      - default:
          cpu: 1
          memory: 500Mi
        defaultRequest:
          cpu: 0.5
          memory: 100Mi
        type: Container


Create the LimitRange object and assign it to the newly created namespace `low-usage-limit`.
You can use `--namespace` or `-n` to specify the namespace.

.. code-block:: bash

    kubectl apply -f low-usage-limit.yaml -n low-usage-limit


By default, `kubectl` looks in the `default` namespace. So the command below will not show the LimitRange object we just created.

.. code-block:: bash

    kubectl get limitrange


To see the LimitRange object, we need to specify the namespace:

.. code-block:: bash

    kubectl get limitrange -n low-usage-limit

    NAME                 CREATED AT
    low-resource-range   2026-05-06T01:59:16Z


.. note::

    A LimitRange in Kubernetes defines per-object constraints inside a namespace.

    If a pod does not specify any resource requests or limits, it will be assigned the default values specified in the LimitRange object.

    If a pod specifies resource requests or limits that exceed the allowed values defined by the LimitRange, it will be rejected by the Kubernetes API server.


Now we will create a deployment in the `low-usage-limit` namespace and observe how resource limits are applied to pods in that namespace.

.. code-block:: bash

    kubectl -n low-usage-limit create deployment limited-hog --image vish/stress


Now get the details of the deployment:

.. code-block:: bash

    kubectl -n low-usage-limit get deployments -o wide

    NAME          READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS   IMAGES        SELECTOR
    limited-hog   1/1     1            1           89s   stress       vish/stress   app=limited-hog


.. code-block:: bash

    kubectl -n low-usage-limit describe deployment limited-hog


    Name:                   limited-hog
    Namespace:              low-usage-limit
    CreationTimestamp:      Wed, 06 May 2026 02:25:33 +0000
    Labels:                 app=limited-hog
    Annotations:            deployment.kubernetes.io/revision: 1
    Selector:               app=limited-hog
    Replicas:               1 desired | 1 updated | 1 total | 1 available | 0 unavailable
    StrategyType:           RollingUpdate
    MinReadySeconds:        0
    RollingUpdateStrategy:  25% max unavailable, 25% max surge


.. code-block:: bash

    kubectl -n low-usage-limit get pods

    NAME                           READY   STATUS    RESTARTS   AGE
    limited-hog-5876fb44bf-vs9q2   1/1     Running   0          3m26s


.. code-block:: bash

    kubectl -n low-usage-limit get pod limited-hog-5876fb44bf-vs9q2 -o wide

    NAME                           READY   STATUS    RESTARTS   AGE    IP               NODE               NOMINATED NODE   READINESS GATES
    limited-hog-5876fb44bf-vs9q2   1/1     Running   0          172m   192.168.244.25   ip-172-31-29-155   <none>           <none>


.. code-block:: bash

    kubectl -n low-usage-limit get pod limited-hog-5876fb44bf-vs9q2 -o yaml

    ...
    ...
    spec:
      containers:
      - image: vish/stress
        imagePullPolicy: Always
        name: stress
        resources:
          limits:
            cpu: "1"
            memory: 500Mi
          requests:
            cpu: 500m
            memory: 100Mi
        terminationMessagePath: /dev/termination-log
        terminationMessagePolicy: File
        volumeMounts:
        - mountPath: /var/run/secrets/kubernetes.io/serviceaccount
          name: kube-api-access-6hwx2
          readOnly: true


From the above output, you can see that the resource limits specified in the LimitRange object have been applied to the pod.
The CPU limit is set to 1 and the memory limit is set to 500Mi, which are the default values specified in the LimitRange object.

Now if we use the older `hog.yaml` file to create a deployment in the `low-usage-limit` namespace, we first:

.. code-block:: bash

    cp hog.yaml hog2.yaml


Then replace the `default` namespace with `low-usage-limit` in the `hog2.yaml` file:

.. code-block:: yaml

    apiVersion: apps/v1
    kind: Deployment
    metadata:
      annotations:
        deployment.kubernetes.io/revision: "1"


Now create a deployment using the `hog2.yaml` file:

.. code-block:: bash

    kubectl apply -f hog2.yaml -n low-usage-limit


    kubectl get deployments -n low-usage-limit

    NAME          READY   UP-TO-DATE   AVAILABLE   AGE
    hog           1/1     1            1           66s
    limited-hog   1/1     1            1           3h13m


In your setup, the **pod spec and the namespace `LimitRange` serve different roles**, which is why your pod is not rejected.

The **pod spec explicitly defines resource `requests` and `limits` (e.g. 1 CPU / 1Gi request, 2 CPU / 4Gi limit)**, and these values always take precedence
when provided.

In contrast, the **namespace `LimitRange` only defines `default` and `defaultRequest` values**, which act as fallbacks — they are applied only if a pod does not specify resources at all.

Since your pod already includes explicit values, those defaults are ignored.

Importantly, your `LimitRange` does **not** include enforcing fields like `min`, `max`, or `maxLimitRequestRatio`, so it does not impose restrictions — only defaults.

That is the key difference: the pod spec sets actual resource usage, while the namespace `LimitRange` in your case merely provides optional defaults, not limits, so there is nothing to reject the pod.