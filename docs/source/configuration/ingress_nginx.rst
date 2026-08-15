ingress-nginx
=============

Purpose
-------

ingress-nginx supplies Kubernetes ingress routing. Its controller metrics make
request volume, status codes, latency, and connection behavior available to
Prometheus and Grafana.

Configuration decisions
-----------------------

``charts/ingress-nginx/ingress-nginx-values.yaml`` enables the controller
metrics endpoint and ServiceMonitor. The monitor carries
``release: prometheus`` so it matches the cross-namespace Prometheus selector.
The existing NodePort service choice is unchanged.

Enabling collection does not install a dedicated ingress dashboard. Metrics
can be queried through Explore or used in a reviewed dashboard.

Verification
------------

.. code-block:: promql

   up{namespace="ingress-nginx"}

Controller metric names commonly begin with
``nginx_ingress_controller_``.
