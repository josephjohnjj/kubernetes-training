Jobs
===================================

Jobs are a Kubernetes resource that allows you to run a task to completion. A Job creates one or more Pods and ensures that a specified number 
of them successfully terminate. As Pods successfully complete, the Job tracks the successful completions. When a specified number of successful 
completions is reached, the Job itself is complete.

Create a Job using the following YAML `job.yml` definition:

.. code-block:: yaml

    apiVersion: batch/v1
    kind: Job
    metadata:
      name: sleepy

    spec:
      template:
        spec:
          containers:
            - name: resting
              image: busybox
              command: ["/bin/sleep"]
              args: ["3"]
          restartPolicy: Never



Apply the Job definition:

.. code-block:: bash

    kubectl apply -f job.yml


Check the status of the Job:

.. code-block:: bash

    kubectl get jobs

    NAME     STATUS     COMPLETIONS   DURATION   AGE
    sleepy   Complete   1/1           7s         63s


Describe the Job to see more details:


.. code-block:: bash

    kubectl describe jobs.batch sleepy

    kubectl describe jobs sleepy


You can also get the details of the Job in YAML format

.. code-block:: bash

    kubectl get jobs sleepy -o yaml


Now delete the Job:

.. code-block:: bash

    kubectl delete job sleepy


Even after a Kubernetes Job finishes successfully, the Job object and its Pods still remain in the cluster unless they are cleaned up.
So deleting a finished Job is mainly about:

* cleanup

* reducing clutter

* freeing resources

* avoiding accumulation of old objects


Now change the completions field in the Job definition to 5 and apply the changes:

.. code-block:: yaml

    apiVersion: batch/v1
    kind: Job
    metadata:
      name: sleepy

    spec:
      completions: 5
      template:
        spec:
          containers:
            - name: resting
              image: busybox
              command: ["/bin/sleep"]
              args: ["3"]
          restartPolicy: Never


Now apply the change and check the status of the Job again:

.. code-block:: bash

    kubectl apply -f job.yml


    kubectl get jobs

    NAME     STATUS    COMPLETIONS   DURATION   AGE
    sleepy   Running   1/5           10s        10s
    kubectl get jobs

The job will eventually complete when all 5 completions are reached:

.. code-block:: bash

    NAME     STATUS     COMPLETIONS   DURATION   AGE
    sleepy   Complete   5/5           30s        39s


You can also check the status of the Pods created by the Job:

.. code-block:: bash

    NAME                   READY   STATUS      RESTARTS   AGE

    sleepy-7h2lg           0/1     Completed   0          41s
    sleepy-c2dwb           0/1     Completed   0          17s
    sleepy-cs4wk           0/1     Completed   0          23s
    sleepy-hjnlf           0/1     Completed   0          35s
    sleepy-rjvnw           0/1     Completed   0          29s


Now delete the Job again:

.. code-block:: bash

    kubectl delete job sleepy

Now add the parallelism field to the Job definition and set it to 2:

.. code-block:: yaml

    apiVersion: batch/v1
    kind: Job
    metadata:
      name: sleepy

    spec:
      completions: 5
      parallelism: 2
      template:
        spec:
          containers:
            - name: resting
              image: busybox
              command: ["/bin/sleep"]
              args: ["3"]
          restartPolicy: Never


Now apply the change and check the status of the Job again:

.. code-block:: bash

    kubectl apply -f job.yml

This will allow up to 2 Pods to run in parallel to complete the Job. You can check the status of the Pods to see that 2 Pods are running at 
the same time:


.. code-block:: bash

  kubectl get pods

  NAME                   READY   STATUS      RESTARTS   AGE

  sleepy-8b2q8           1/1     Running     0          3s
  sleepy-cbw8n           0/1     Completed   0          9s
  sleepy-d9tnp           0/1     Completed   0          16s
  sleepy-dd52f           0/1     Completed   0          9s
  sleepy-qk7dw           0/1     Completed   0          16s


Now change the `activeDeadlineSeconds: 15` in the Job definition and apply the change:

.. code-block:: yaml

    apiVersion: batch/v1
    kind: Job
    metadata:
      name: sleepy

    spec:
      completions: 5
      parallelism: 2
      activeDeadlineSeconds: 15
      template:
        spec:
          containers:
            - name: resting
              image: busybox
              command: ["/bin/sleep"]
              args: ["3"]
          restartPolicy: Never



.. code-block:: bash

    kubectl delete job sleepy


.. code-block:: bash

    kubectl apply -f job.yml


Now check the status of the Job again:

.. code-block:: bash

    kubectl get jobs

    NAME     STATUS   COMPLETIONS   DURATION   AGE
    sleepy   Failed   4/5           2m48s      2m48s

You can get more details about the Job to see why it failed:

.. code-block:: bash

    kubectl get job sleepy -o yaml

    - lastProbeTime: "2026-05-12T12:32:44Z"
      lastTransitionTime: "2026-05-12T12:32:44Z"
      message: Job was active longer than specified deadline
      reason: DeadlineExceeded
      status: "True"
      type: Failed
  