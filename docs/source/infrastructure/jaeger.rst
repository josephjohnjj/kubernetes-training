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

Argo CD deploys the repository chart through
``argocd/infrastructure/observability/jaeger/01-jaeger.yaml`` into namespace
``jaeger``:

.. code-block:: bash

   kubectl -n argocd get application jaeger
   kubectl -n jaeger get pods,services

HTTPS ingress
-------------

Keep the Jaeger Service private. The ``platform-ingresses`` Application
manages ``argocd/ingresses/04-jaeger-ingress.yaml``, which requests the trusted
``jaeger-ingress-tls`` certificate and redirects HTTP to HTTPS:

.. code-block:: bash

   kubectl -n jaeger get ingress jaeger
   kubectl -n jaeger get certificate jaeger-ingress-tls
   curl -I https://jaeger.44.203.188.20.nip.io

TLS terminates at ingress-nginx, which forwards browser requests to the Jaeger
query Service on cluster-local HTTP port 16686. OTLP ingestion remains a
separate cluster-local endpoint and does not pass through this UI Ingress.

Verification
------------

Check that Jaeger components are running:

.. code-block:: bash

   kubectl get pods -n jaeger

Check services:

.. code-block:: bash

   kubectl get svc -n jaeger

Verify the Jaeger service endpoints:

.. code-block:: bash

   kubectl describe svc jaeger -n jaeger

Testing Connectivity
--------------------

You can test connectivity to the cluster using a temporary curl pod:

.. code-block:: bash

   kubectl run curl --rm -it --image=curlimages/curl --restart=Never -- sh

Once inside the pod, you can query Jaeger endpoints or services exposed in the cluster.
