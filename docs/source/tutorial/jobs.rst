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


You can also get the details of the Job in YAML format:

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


Cron Jobs
-------------


A Linux cron job is a scheduled task that runs automatically at specific times or intervals.

.. note::


    .. code-block:: text

        * * * * * command_to_run
        │ │ │ │ │
        │ │ │ │ └── Day of week (0-7) (Sun=0 or 7)
        │ │ │ └──── Month (1-12)
        │ │ └────── Day of month (1-31)
        │ └──────── Hour (0-23)
        └────────── Minute (0-59)


    Each * in the cron schedule represents a wildcard that matches any value for that time unit. For example, if you have a cron job with the
    schedule `0 0 * * *`, it will run at midnight every day, regardless of the day of the month or the month itself.

    .. code-block:: bash

        * * * * * echo "Hello"

    This cron job will print "Hello" to the console every minute, regardless of the hour, day, month, or day of the week. The * allows the cron job
    to run at every possible value for those time units.

    .. code-block:: bash

        30 2 * * * /home/user/backup.sh

    This cron job will run the `backup.sh` script at 2:30 AM every day, regardless of the day of the month, month, or day of the week.


    .. code-block:: bash

      */5 * * * * python3 script.py

    This cron job will run the `script.py` Python script every 5 minutes, regardless of the hour, day, month, or day of the week. The `*/5` in the minute
    field means "every 5 minutes".


In Kubernetes a `CronJob` creates a watch loop which will create a batch Job on your behalf when the time becomes true.
The CronJob controller inside Kubernetes continuously checks the current time against the schedule you defined.
When the current time matches the cron schedule, the CronJob controller creates a new `Job object` based on the template you provided
in the CronJob specification. This will in turn create one or more Pods to run the task defined in the Job. The CronJob controller also manages
the lifecycle of the Jobs it creates, ensuring that they are executed according to the schedule and that any failed Jobs are retried if necessary.



Now create a CronJob using the following YAML `cronjob.yml` definition:

.. code-block:: yaml

    apiVersion: batch/v1
    kind: CronJob
    metadata:
      name: sleepy
    spec:
      schedule: "*/2 * * * *"
      jobTemplate:
        spec:
          template:
            spec:
              containers:
                - name: resting
                  image: busybox
                  command: ["/bin/sleep"]
                  args: ["5"]
              restartPolicy: Never


Apply the CronJob definition:

.. code-block:: bash

    kubectl apply -f cronjob.yml


.. code-block:: bash

    kubectl get cronjobs

    NAME     SCHEDULE      TIMEZONE   SUSPEND   ACTIVE   LAST SCHEDULE   AGE
    sleepy   */2 * * * *   <none>     False     0        <none>          21s

    kubectl get cronjobs

    NAME     SCHEDULE      TIMEZONE   SUSPEND   ACTIVE   LAST SCHEDULE   AGE
    sleepy   */2 * * * *   <none>     False     0        45s             81s


.. code-block:: bash

    kubectl get jobs

    NAME              STATUS     COMPLETIONS   DURATION   AGE

    sleepy-29643846   Complete   1/1           8s         2m6s
    sleepy-29643848   Running    0/1           6s         6s


.. note::

  This `CronJob` runs every 2 minutes because the schedule `"*/2 * * * *"` matches every second minute. When you first ran `kubectl get cronjobs`,
  `LAST SCHEDULE` was `<none>` because the CronJob had not yet reached its first scheduled execution time, and `ACTIVE` was `0`
  because no Job was running yet. After the first schedule occurred, `LAST SCHEDULE` showed how long ago the CronJob last created a Job.
  The `ACTIVE` column still remained `0` because the container only executes `sleep 5`, so the Job finishes very quickly.
  Running `kubectl get jobs` shows the individual Jobs automatically created by the CronJob controller. One Job was already
  `Complete`, meaning its Pod successfully finished, while another was still `Running` because its Pod was currently executing the
  `sleep 5` command. Each scheduled execution creates a separate Job with an auto-generated name such as `sleepy-29643846`.


A `CronJob` will not automatically delete itself after completion. The `CronJob` object will remain in the cluster until
you manually delete it.

Similar to 'Jobs', you can also specify `parallelism`, `completions`, and `activeDeadlineSeconds` in the Job template of the CronJob definition to
control how the Jobs created by the CronJob will run.