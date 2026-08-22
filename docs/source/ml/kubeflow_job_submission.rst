Kubeflow Job Submission and Monitoring
======================================

This page starts after the Linux user and restricted kubeconfig have been
created as described in :doc:`login_node_user_onboarding`.

Enable the training runtime
---------------------------

The CPU examples use the cluster-scoped ``torch-distributed`` runtime. The
``kubeflow-trainer`` Argo CD Application enables it with this Helm override:

.. code-block:: yaml

   helm:
     valuesObject:
       runtimes:
         torchDistributed:
           enabled: true

After the parent ``infrastructure`` Application and child
``kubeflow-trainer`` Application synchronize, verify it:

.. code-block:: console

   kubectl get clustertrainingruntime torch-distributed

If the child has not received the override, hard-refresh both layers:

.. code-block:: console

   kubectl -n argocd annotate application infrastructure \
     argocd.argoproj.io/refresh=hard --overwrite
   kubectl -n argocd annotate application kubeflow-trainer \
     argocd.argoproj.io/refresh=hard --overwrite

Submit the CPU smoke test
-------------------------

Every user TrainJob must use ``mlproject`` and select the CPU LocalQueue:

.. code-block:: yaml

   metadata:
     namespace: mlproject
     labels:
       kueue.x-k8s.io/queue-name: cpu-normal-queue

Examples under ``ml/trainjobs`` are outside Argo CD's managed directories, so
committing them does not execute them. Submit the smoke test from the login
node:

.. code-block:: console

   cd ~/kubernetes-training
   sudo -u mluser1 kubectl create \
     -f ml/trainjobs/01-cpu-smoke-test.yaml

Kubeflow Trainer creates the training workload. Kueue holds it until CPU and
memory quota are available.

Monitor from the login node
---------------------------

When an administrator tests the user workflow, ``sudo -u mluser1`` selects
``/home/mluser1/.kube/config``:

.. code-block:: console

   sudo -u mluser1 kubectl get trainjob cpu-smoke-test
   sudo -u mluser1 kubectl get workloads
   sudo -u mluser1 kubectl get pods --watch

After quota is reserved, the Workload reports ``ADMITTED=True`` and Kueue
changes TrainJob suspension to ``false``:

.. code-block:: console

   sudo -u mluser1 kubectl get trainjob cpu-smoke-test \
     -o jsonpath='suspend={.spec.suspend}{"\n"}'

Follow the Pod output:

.. code-block:: console

   POD=$(sudo -u mluser1 kubectl get pods \
     -l jobset.sigs.k8s.io/jobset-name=cpu-smoke-test \
     -o jsonpath='{.items[0].metadata.name}')
   sudo -u mluser1 kubectl logs "$POD" --follow

The Pod can remain in ``ContainerCreating`` while the worker downloads the
large PyTorch image.

Monitor from a control node
---------------------------

``mluser1`` exists only on the login node. On ``control1``, use the
administrator kubeconfig and explicit namespace instead of
``sudo -u mluser1``:

.. code-block:: console

   kubectl -n mlproject get trainjob cpu-smoke-test
   kubectl -n mlproject get workloads
   kubectl -n mlproject get jobsets
   kubectl -n mlproject get pods -o wide

Check the authoritative suspension fields:

.. code-block:: console

   kubectl -n mlproject get trainjob cpu-smoke-test \
     -o jsonpath='suspend={.spec.suspend}{"\n"}'
   kubectl -n mlproject get jobset cpu-smoke-test \
     -o jsonpath='suspend={.spec.suspend}{"\n"}'

The TrainJob printer's ``STATE`` can briefly display ``Suspended`` after
``spec.suspend`` becomes ``false``. The spec, JobSet state, and presence of a
Pod are better indicators during this transition.

.. code-block:: console

   kubectl -n mlproject describe trainjob cpu-smoke-test
   kubectl -n mlproject get events --sort-by='.lastTimestamp'
   kubectl -n mlproject logs POD_NAME --follow

Webhook certificate recovery
----------------------------

An ``x509: certificate signed by unknown authority`` error means the Trainer
webhook serving certificate and CA bundle are inconsistent. First restart the
controller:

.. code-block:: console

   kubectl -n kubeflow-system rollout restart \
     deployment/kubeflow-trainer-controller-manager
   kubectl -n kubeflow-system rollout status \
     deployment/kubeflow-trainer-controller-manager --timeout=2m

If the error remains, rotate only the generated certificate Secret:

.. code-block:: console

   kubectl -n kubeflow-system delete secret kubeflow-trainer-webhook-cert
   kubectl -n kubeflow-system create secret generic \
     kubeflow-trainer-webhook-cert
   kubectl -n kubeflow-system get secret kubeflow-trainer-webhook-cert

Wait until it reports ``DATA 4``, then restart the controller again. The
rotator repopulates the Secret and updates the webhooks. Do not disable webhook
validation.

Next step
---------

Continue with :doc:`persistent_training_and_tracing` to save artifacts on the
shared PVC and export application traces to Jaeger.
