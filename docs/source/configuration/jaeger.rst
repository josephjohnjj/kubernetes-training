Jaeger
======

Purpose
-------

Jaeger stores and queries distributed traces. Grafana presents those traces
alongside metrics and logs.

Configuration decisions
-----------------------

Jaeger is deployed in the ``jaeger`` namespace. Grafana connects to its
cluster-local query service at ``http://jaeger.jaeger.svc.cluster.local:16686``
using proxy access. The service is not exposed solely for Grafana.

Adding the data source does not instrument workloads. Trace producers must send
supported Jaeger or OpenTelemetry data to the collector.

Verification
------------

.. code-block:: console

   kubectl get service -n jaeger jaeger

In Grafana, open Jaeger under **Connections > Data sources**, select **Save &
test**, and use it in Explore. An empty list is expected until spans arrive.
