Instrumenting TrainJobs with OpenTelemetry
==========================================

This guide explains what every Python TrainJob must provide to emit traces to
the platform Jaeger service. It uses
``ml/trainjobs/02-cpu-pvc-training.yaml`` as the reference implementation.
See :doc:`persistent_training_and_tracing` for submitting that example and
finding its trace in the Jaeger UI.

Telemetry path
--------------

Each training process creates spans through the OpenTelemetry API. The SDK
batches and serializes those spans, and the OTLP HTTP exporter sends them to
Jaeger:

.. code-block:: text

   instrumented Python code
       |
       v
   OpenTelemetry API and SDK
       |
       | OTLP/HTTP protobuf
       v
   http://jaeger.jaeger.svc.cluster.local:4318/v1/traces
       |
       v
   Jaeger storage and query UI

The application emits spans, not Jaeger-specific files. Model artifacts,
metrics files, checkpoints, and datasets remain separate and should be stored
on the PVC or another artifact store.

Requirements for every instrumented job
---------------------------------------

Every job must:

#. Include the OpenTelemetry API, SDK, and matching OTLP exporter in its Python
   environment.
#. Create a ``TracerProvider`` with a stable, meaningful ``service.name``.
#. Attach an exporter that targets the platform's OTLP HTTP trace endpoint.
#. Register the provider globally with ``trace.set_tracer_provider``.
#. Obtain a tracer and create a root span for one logical training run.
#. Create child spans around meaningful stages such as input loading,
   preprocessing, training, evaluation, checkpointing, and artifact storage.
#. Add small, searchable attributes that identify the run and summarize its
   outcome.
#. Record failures through span context managers instead of swallowing them.
#. Flush and shut down the provider before the short-lived process exits.
#. Use a unique Kubernetes TrainJob name when retaining previous runs, or
   delete the completed object before recreating the same name.

1. Provide the Python dependencies
-----------------------------------

The reference manifest installs the minimum packages before starting Python:

.. code-block:: yaml

   command:
     - /bin/bash
     - -c
   args:
     - |
       set -euo pipefail

       pip install --no-cache-dir --break-system-packages \
         opentelemetry-api \
         opentelemetry-sdk \
         opentelemetry-exporter-otlp-proto-http

       python - <<'PY'
       # Instrumented program
       PY

``set -euo pipefail`` stops the container if dependency installation or the
training program fails. ``--break-system-packages`` is required by the current
PEP 668-managed runtime image. Because the container is disposable, this does
not modify a worker node's host Python installation.

Startup installation is useful for a demonstration but depends on external
package-index access and makes runs less reproducible. Production jobs should
use a versioned image containing compatible, pinned OpenTelemetry packages.

2. Identify the service and job
-------------------------------

Create a Resource before creating spans:

.. code-block:: python

   from opentelemetry.sdk.resources import Resource

   resource = Resource.create({
       "service.name": "cpu-pvc-training",
       "service.namespace": "mlproject",
       "ml.user": "mluser1",
       "k8s.namespace.name": "mlproject",
   })

``service.name`` is mandatory for usability because it becomes the **Service**
selection in Jaeger. Choose a stable workload name such as
``image-classifier-training`` rather than a Pod name or timestamp. Put the
individual run identifier in an attribute such as ``ml.run.id``.

Recommended Resource attributes include:

.. list-table::
   :header-rows: 1
   :widths: 35 65

   * - Attribute
     - Purpose
   * - ``service.name``
     - Stable application or training-workload name shown in Jaeger.
   * - ``service.namespace``
     - Logical platform or Kubernetes namespace grouping.
   * - ``k8s.namespace.name``
     - Kubernetes namespace in which the TrainJob executes.
   * - ``ml.user``
     - Submitting user or team when permitted by local data policy.
   * - ``service.version``
     - Training image, code, or model-training version.

Do not put credentials, access tokens, personal data, or unbounded values into
Resource attributes.

3. Configure the OTLP exporter
------------------------------

The reference job configures OTLP over HTTP explicitly:

.. code-block:: python

   from opentelemetry import trace
   from opentelemetry.exporter.otlp.proto.http.trace_exporter import (
       OTLPSpanExporter,
   )
   from opentelemetry.sdk.trace import TracerProvider
   from opentelemetry.sdk.trace.export import BatchSpanProcessor

   provider = TracerProvider(resource=resource)
   exporter = OTLPSpanExporter(
       endpoint="http://jaeger.jaeger.svc.cluster.local:4318/v1/traces"
   )
   provider.add_span_processor(BatchSpanProcessor(exporter))
   trace.set_tracer_provider(provider)
   tracer = trace.get_tracer("ml-training")

The endpoint parts are significant:

.. list-table::
   :header-rows: 1
   :widths: 30 70

   * - Value
     - Meaning
   * - ``jaeger``
     - Kubernetes Service name.
   * - ``jaeger.svc.cluster.local``
     - Service namespace and cluster DNS suffix.
   * - ``4318``
     - Jaeger's OTLP HTTP receiver port.
   * - ``/v1/traces``
     - OTLP HTTP path for trace export.

Do not substitute the Jaeger Pod IP; it changes when the Pod is replaced. Do
not send an HTTP exporter to port ``4317`` because that port expects OTLP gRPC.

4. Define the trace hierarchy
-----------------------------

Create one root span for the complete logical run and child spans for major
operations:

.. code-block:: python

   with tracer.start_as_current_span("training-run") as run_span:
       run_span.set_attribute("ml.framework", "pytorch")
       run_span.set_attribute("ml.device", "cpu")

       with tracer.start_as_current_span("load-data"):
           features, targets = load_training_data()

       with tracer.start_as_current_span("train-model") as training_span:
           model, loss = train(features, targets)
           training_span.set_attribute("ml.epochs", epochs)
           training_span.set_attribute("ml.final_loss", float(loss))

       with tracer.start_as_current_span("save-results") as storage_span:
           model_path = save_model(model)
           storage_span.set_attribute("ml.model.path", str(model_path))

Keep spans at useful operation boundaries. Creating a span for every sample,
batch, or tensor operation produces excessive telemetry and obscures the
overall run.

The context manager automatically makes nested spans children of the current
span. If an exception escapes the block, the SDK records the exception and
marks the span as failed before Python propagates the error.

5. Add useful attributes
------------------------

Attributes should be small values that help distinguish and diagnose runs:

* Run identifier and code or image version.
* Framework and compute device.
* Epoch, sample, worker, or node counts.
* Final loss and evaluation score.
* Dataset name or version, but not the dataset contents.
* Persistent artifact paths, but not the artifacts themselves.
* Distributed rank and world size for multi-process training.

Convert framework-specific scalar objects to native Python values before
attaching them:

.. code-block:: python

   span.set_attribute("ml.final_loss", float(loss.item()))
   span.set_attribute("ml.samples", int(len(features)))

Attribute keys should remain consistent across jobs so Jaeger queries and
future dashboards can compare them.

6. Flush before the container exits
-----------------------------------

``BatchSpanProcessor`` exports asynchronously. A Kubernetes training process
can finish before its final batch is sent, so always use ``finally``:

.. code-block:: python

   try:
       with tracer.start_as_current_span("training-run"):
           run_training()
   finally:
       provider.force_flush()
       provider.shutdown()

Create the provider before entering ``try``. Do not call ``os._exit`` or
otherwise bypass the ``finally`` block. A completed TrainJob without this
flush does not guarantee that Jaeger received its final spans.

7. Preserve Kubernetes and Kueue requirements
----------------------------------------------

Instrumentation does not replace the fields needed to schedule the job. A CPU
TrainJob must still include:

.. code-block:: yaml

   metadata:
     namespace: mlproject
     labels:
       kueue.x-k8s.io/queue-name: cpu-normal-queue
   spec:
     runtimeRef:
       name: torch-distributed
       kind: ClusterTrainingRuntime
     trainer:
       numNodes: 1
       resourcesPerNode:
         requests:
           cpu: "500m"
           memory: 512Mi
         limits:
           cpu: "1"
           memory: 1Gi

If the job writes artifacts, retain the PVC ``volume`` and ``volumeMount``
patch demonstrated in ``02-cpu-pvc-training.yaml``. Change the output path so
each user and workload writes to its intended directory.

8. Adapt the reference manifest
-------------------------------

When copying ``02-cpu-pvc-training.yaml`` for a new job, review every item in
this table:

.. list-table::
   :header-rows: 1
   :widths: 34 66

   * - Reference value
     - Required decision
   * - ``metadata.name``
     - Choose a DNS-safe, unique TrainJob name.
   * - ``cpu-normal-queue``
     - Select the authorized LocalQueue for the requested compute type.
   * - Trainer image
     - Use a trusted, versioned image containing the application dependencies.
   * - Resource requests and limits
     - Declare realistic CPU and memory requirements for Kueue admission.
   * - ``service.name``
     - Choose the stable service name users will select in Jaeger.
   * - ``ml.user``
     - Set the submitting user or replace it with an approved team identifier.
   * - Root and child span names
     - Model the meaningful stages of the new program.
   * - Span attributes
     - Record bounded identifiers, configuration, outcomes, and artifact paths.
   * - Results directory
     - Use the correct user, project, workload, and unique-run path.
   * - PVC claim and mount
     - Select storage the namespace and user are authorized to use.

Multi-node and multi-process jobs
--------------------------------

Every Python process that initializes a provider emits its own trace. For a
distributed job, add attributes such as ``process.pid``, ``ml.worker.rank``,
``ml.world_size``, Pod name, and node name. Use a shared run identifier to
correlate workers.

Independent workers do not automatically share one parent span. Creating a
single distributed trace requires propagating OpenTelemetry trace context from
the coordinator to workers. Until that propagation is implemented, use the
shared run identifier to find all worker traces and avoid implying that
separate traces have a parent-child relationship.

Validation checklist
--------------------

Before handing a new instrumented TrainJob to users, verify:

.. code-block:: console

   kubectl -n jaeger get service jaeger
   kubectl -n jaeger get endpointslice \
     -l kubernetes.io/service-name=jaeger
   kubectl get clustertrainingruntime torch-distributed

After submission, verify:

* The Kueue Workload is admitted and eventually finished.
* The TrainJob and Pod complete without restarts.
* Pod logs contain no package-installation or exporter errors.
* The new ``service.name`` appears in Jaeger.
* The root span and expected child spans are present.
* Run attributes and artifact paths are correct and contain no sensitive data.

Authoring checklist
-------------------

Use this abbreviated checklist for every job:

.. code-block:: text

   [ ] OpenTelemetry packages are present in the image or installed at startup
   [ ] service.name is stable and meaningful
   [ ] OTLP HTTP endpoint is :4318/v1/traces
   [ ] one root span represents the complete run
   [ ] child spans represent major job stages
   [ ] attributes are bounded, useful, and non-sensitive
   [ ] errors can escape span context managers
   [ ] provider is flushed and shut down in finally
   [ ] namespace, Kueue label, runtime, and resources remain configured
   [ ] PVC paths are unique and authorized when artifacts are persisted
   [ ] completed trace is discoverable in Jaeger
