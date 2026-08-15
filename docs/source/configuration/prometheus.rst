Prometheus
==========

Purpose
-------

Prometheus stores cluster metrics and supplies Grafana's default metrics data
source. It is installed with Grafana, Alertmanager, kube-state-metrics, and the
node exporter through ``kube-prometheus-stack``.

Configuration decisions
-----------------------

The Argo CD Application uses
``charts/prometheus-stack/prometheus-stack-values.yaml`` and deploys into the
``prometheus`` namespace. Prometheus selects ``ServiceMonitor`` objects with:

.. code-block:: yaml

   release: prometheus

Its ServiceMonitor namespace selector permits discovery across namespaces. The
same label is therefore added to Fluent Bit, ingress-nginx, Argo Workflows,
Kyverno, and Trivy monitors. This explicit selector prevents unrelated monitors
from being scraped accidentally.

Verification
------------

Port-forward Prometheus and inspect ``/targets``:

.. code-block:: console

   kubectl port-forward -n prometheus \
     svc/prometheus-kube-prometheus-prometheus 9090:9090

In Prometheus or Grafana Explore, query ``up``. A value of ``1`` means the
target is being scraped successfully. Filter by ``namespace`` to inspect a
specific component.
