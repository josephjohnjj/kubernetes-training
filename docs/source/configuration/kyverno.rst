Kyverno
=======

Purpose
-------

Kyverno applies Kubernetes admission and background policies. Its metrics make
policy decisions, failures, execution latency, and controller health visible.

Configuration decisions
-----------------------

The Argo CD Application reads ``charts/kyverno/kyverno-values.yaml``. A
ServiceMonitor is enabled for each Kyverno component:

* admission controller
* background controller
* cleanup controller
* reports controller

Every monitor carries ``release: prometheus``. Enabling metrics does not alter
policy enforcement or introduce new policies.

Verification
------------

.. code-block:: console

   kubectl get servicemonitor -n kyverno

.. code-block:: promql

   up{namespace="kyverno"}

Dedicated dashboards were not added. Panels can be built from collected
``kyverno_*`` series after confirming metric names in the live cluster.
