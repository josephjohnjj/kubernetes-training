Cluster Configuration Decisions
===============================

This section records the decisions made for cluster-level observability. It
complements the installation guides under ``infrastructure`` by explaining the
desired data flow, Git-managed settings, rationale, and operational effects. It
intentionally excludes application-level configuration.

.. code-block:: text

   Metrics --> Prometheus -------------------+
                                              |
   Logs --> Fluent Bit --> OpenSearch --------+--> Grafana
                                              |
   Traces --> Jaeger -------------------------+

Argo CD follows ``main`` for these infrastructure applications and applies the
Helm override files named on each page. Changes should be committed, pushed,
allowed to synchronize, and verified in the live cluster.

.. warning::

   Some current values contain the OpenSearch administrator password in
   plaintext and disable TLS certificate verification. These choices describe
   the deployed configuration, but should be replaced with Secret references
   and trusted cluster certificates before production use.

.. toctree::
   :maxdepth: 1

   grafana
   prometheus
   fluent_bit
   opensearch
   jaeger
   ingress_nginx
   argo_workflows
   kyverno
   trivy
