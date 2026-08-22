Persistent Training and Jaeger Tracing
======================================

The example ``ml/trainjobs/02-cpu-pvc-training.yaml`` combines a persistent
PyTorch workload with OpenTelemetry tracing. Complete
:doc:`login_node_user_onboarding` and :doc:`kubeflow_job_submission` first.

What the example does
---------------------

The TrainJob:

* Learns a linear model on one CPU worker.
* Runs through Kueue's ``cpu-normal-queue``.
* Mounts ``mlproject-pvc`` at ``/mnt/mlproject``.
* Saves ``model.pt`` and ``metrics.json`` after training.
* Exports OpenTelemetry spans to the in-cluster Jaeger service.

One run creates:

.. code-block:: text

   /mnt/mlproject/results/mluser1/cpu-pvc-training/
   |-- latest.txt
   `-- 20260821T070000Z/
       |-- metrics.json
       `-- model.pt

``latest.txt`` identifies the most recently completed run. Timestamped
directories prevent later runs from overwriting earlier artifacts.

Submit and monitor the job
--------------------------

Submit from the login node as the restricted user:

.. code-block:: console

   cd ~/kubernetes-training
   sudo -u mluser1 kubectl create \
     -f ml/trainjobs/02-cpu-pvc-training.yaml

To rerun the same named example, delete and recreate it:

.. code-block:: console

   sudo -u mluser1 kubectl delete trainjob cpu-pvc-training
   sudo -u mluser1 kubectl create \
     -f ml/trainjobs/02-cpu-pvc-training.yaml

Monitor it from the control node:

.. code-block:: console

   kubectl -n mlproject get trainjobs,workloads,jobsets,pods
   kubectl -n mlproject get pods -w
   kubectl -n mlproject logs \
     -l jobset.sigs.k8s.io/jobset-name=cpu-pvc-training \
     --all-containers=true --follow

OpenTelemetry output model
--------------------------

OpenTelemetry traces are not normally written to model-output files. The SDK
creates in-memory spans, batches them, and exports them to Jaeger over
OTLP/HTTP:

.. code-block:: text

   PyTorch process
       |
       | OpenTelemetry spans (OTLP/HTTP)
       v
   http://jaeger.jaeger.svc.cluster.local:4318/v1/traces
       |
       v
   Jaeger trace storage and query UI

``model.pt`` and ``metrics.json`` go to the PVC; trace spans go to Jaeger. If a
durable local telemetry file is needed for debugging, configure an additional
file or console exporter rather than treating the OTLP payload as an artifact.

Install the OpenTelemetry client
--------------------------------

The example installs these packages at startup:

.. code-block:: bash

   pip install --no-cache-dir --break-system-packages \
     opentelemetry-api \
     opentelemetry-sdk \
     opentelemetry-exporter-otlp-proto-http

The worker needs package-index access. ``--break-system-packages`` is required
because the runtime image marks Python as externally managed under PEP 668. It
is acceptable for this disposable container. A production image should
contain version-pinned dependencies.

Connect the exporter to Jaeger
------------------------------

The SDK identifies traces with ``service.name=cpu-pvc-training`` and sends
them to Jaeger:

.. code-block:: python

   provider = TracerProvider(
       resource=Resource.create({
           "service.name": "cpu-pvc-training",
           "ml.user": "mluser1",
           "k8s.namespace.name": "mlproject",
       })
   )

   provider.add_span_processor(
       BatchSpanProcessor(
           OTLPSpanExporter(
               endpoint=(
                   "http://jaeger.jaeger.svc.cluster.local:"
                   "4318/v1/traces"
               )
           )
       )
   )

Use the stable Kubernetes Service DNS name, not a Jaeger Pod IP. Port ``4318``
is OTLP HTTP and ``/v1/traces`` is its trace endpoint. Port ``4317`` is OTLP
gRPC and cannot be used by this HTTP exporter.

Create useful spans
-------------------

The example produces this hierarchy:

.. code-block:: text

   cpu-pvc-training-run
   |-- prepare-data
   |-- train-model
   `-- save-results

Attributes including ``ml.framework``, ``ml.device``, ``ml.epochs``,
``ml.samples``, ``ml.final_loss``, ``ml.run.id``, and artifact paths make the
trace useful. Do not attach binaries, datasets, credentials, or high-volume
per-sample values.

Create parent-child relationships with ``start_as_current_span``:

.. code-block:: python

   with tracer.start_as_current_span("train-model") as span:
       for _ in range(300):
           optimizer.zero_grad()
           loss = loss_function(model(features), targets)
           loss.backward()
           optimizer.step()

       span.set_attribute("ml.epochs", 300)
       span.set_attribute("ml.final_loss", loss.item())

Flush short-lived jobs before exit:

.. code-block:: python

   finally:
       provider.force_flush()
       provider.shutdown()

Without this flush, buffered spans can be lost when the container exits.

Verify Jaeger
-------------

From a control node:

.. code-block:: console

   kubectl -n jaeger get pods
   kubectl -n jaeger get service jaeger
   kubectl -n jaeger get endpointslice \
     -l kubernetes.io/service-name=jaeger

The Pod must be ``Running``, the Service must expose ``4318/TCP`` and
``16686/TCP``, and the EndpointSlice must contain a ready backend.

Find the trace
--------------

Wait for the job to finish:

.. code-block:: console

   sudo -u mluser1 kubectl get trainjobs,workloads,pods

The expected final states are ``Complete`` for the TrainJob,
``FINISHED=True`` for the Workload, and ``Completed`` for the Pod. Check the
completed Pod log for exporter warnings:

.. code-block:: console

   POD=$(sudo -u mluser1 kubectl get pods \
     -l jobset.sigs.k8s.io/jobset-name=cpu-pvc-training \
     -o jsonpath='{.items[0].metadata.name}')
   sudo -u mluser1 kubectl logs "$POD"

Open the Jaeger UI:

.. code-block:: text

   https://jaeger.44.203.188.20.nip.io

Then:

#. Select ``cpu-pvc-training`` under **Service**.
#. Leave **Operation** set to ``all``.
#. Set **Lookback** to **Last Hour**, or longer for an older run.
#. Leave the duration fields empty and click **Find Traces**.
#. Open the result with root operation ``cpu-pvc-training-run``.
#. Expand and verify ``prepare-data``, ``train-model``, and ``save-results``.
#. Select a span to inspect its duration, attributes, status, and errors.

If ingress is unavailable, an administrator can port-forward the UI:

.. code-block:: console

   kubectl -n jaeger port-forward service/jaeger 16686:16686

Then open ``http://127.0.0.1:16686``.

Troubleshoot missing traces
---------------------------

If the service does not appear in Jaeger:

#. Confirm that the Pod completed and inspect its logs for ``pip`` or exporter
   errors.
#. Confirm that ``jaeger.jaeger.svc.cluster.local`` resolves from
   ``mlproject`` and port ``4318`` is reachable.
#. Confirm that the endpoint ends in ``/v1/traces``.
#. Confirm that the Jaeger Service exposes ``otlp-http``.
#. Increase the UI lookback and clear service, operation, and tag filters.

An administrator can test connectivity when policy permits temporary Pods:

.. code-block:: console

   kubectl -n mlproject run otlp-connectivity-test \
     --image=curlimages/curl --restart=Never --rm -it -- \
     sh -c 'curl -sv http://jaeger.jaeger.svc.cluster.local:4318/'

An HTTP ``404`` or ``405`` at the receiver root still proves DNS and HTTP
connectivity. Actual exports use ``/v1/traces`` with an OTLP protobuf body. The
restricted user cannot create this diagnostic Pod, so an administrator must
run the test.

Jaeger describes instrumented Python stages. Kueue admission, Kubernetes
scheduling, image pulling, and Kubeflow reconciliation do not automatically
become child spans. Diagnose those stages using Workload status, events, Pod
status, and controller logs.
