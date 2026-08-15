Argo Workflows
==============

Purpose
-------

Argo Workflows schedules and executes workflow resources. Controller metrics
show workflow processing and controller health.

Configuration decisions
-----------------------

``charts/argo-workflows/argo-workflow-values.yaml`` enables the controller
metrics server and ServiceMonitor. The monitor is labeled
``release: prometheus``. Workflow scope remains limited to the
``argo-workflows`` namespace.

Only metrics collection changed. Workflow execution, permissions, and service
exposure were not modified.

Verification
------------

.. code-block:: console

   kubectl get servicemonitor -n argo-workflows

.. code-block:: promql

   up{namespace="argo-workflows"}
