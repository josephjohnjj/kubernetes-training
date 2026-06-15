Jaeger
======

Jaeger is a distributed tracing system used for monitoring and troubleshooting
microservices-based architectures. It helps visualize request flows across services,
identify latency bottlenecks, and debug distributed systems by collecting and
correlating trace data.

Jaeger is commonly used for:

* Identifying latency issues across microservices
* Debugging failed requests in distributed systems
* Understanding service dependencies
* Monitoring request propagation across clusters

Installation
------------

Add the Jaeger Helm repository:

.. code-block:: bash

   helm repo add jaegertracing https://jaegertracing.github.io/helm-charts

Install Jaeger in a dedicated namespace:

.. code-block:: bash

   helm install jaeger jaegertracing/jaeger -n observability --create-namespace

Service Exposure
----------------

Expose the Jaeger UI using a NodePort service for external access:

.. code-block:: bash

   kubectl patch svc jaeger -n observability -p '{"spec":{"type":"NodePort"}}'

Verification
------------

Check that Jaeger components are running:

.. code-block:: bash

   kubectl get pods -n observability

Check services:

.. code-block:: bash

   kubectl get svc -n observability

Verify the Jaeger service endpoints:

.. code-block:: bash

   kubectl describe svc jaeger -n observability

Testing Connectivity
--------------------

You can test connectivity to the cluster using a temporary curl pod:

.. code-block:: bash

   kubectl run curl --rm -it --image=curlimages/curl --restart=Never -- sh

Once inside the pod, you can query Jaeger endpoints or services exposed in the cluster.

