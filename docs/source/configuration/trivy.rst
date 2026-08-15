Trivy Operator
==============

Purpose
-------

Trivy Operator scans cluster workloads and publishes vulnerability and
configuration-audit results. Its metrics provide aggregate security posture in
Prometheus and Grafana.

Configuration decisions
-----------------------

The Argo CD Application reads
``charts/trivy-operator/trivy-operator-values.yaml``. The override enables the
operator ServiceMonitor and labels it ``release: prometheus``. Existing scanner
and report-generation defaults are otherwise unchanged.

Metrics do not replace Kubernetes vulnerability report resources. Grafana is
suitable for trends and totals; individual findings should still be inspected
through Trivy reports.

Verification
------------

.. code-block:: console

   kubectl get servicemonitor -n trivy-system

.. code-block:: promql

   up{namespace="trivy-system"}

Dedicated dashboards were not installed. Review available ``trivy_*`` metrics
before constructing panels or alerts.
