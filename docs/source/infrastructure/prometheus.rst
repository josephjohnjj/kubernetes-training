Prometheus Helm Installation Guide
===================================



First, add the official Prometheus Helm charts repository maintained by the Prometheus community.

.. code-block:: bash

   helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
   helm repo update

Create Namespace
----------------

Create a dedicated namespace for Prometheus components:

.. code-block:: bash

   kubectl create namespace prometheus

Verify Prometheus Pods
----------------------

Check that Prometheus-related pods are running in the namespace:

.. code-block:: bash

   kubectl --namespace prometheus get pods -l "release=prometheus"

Expose Grafana via NodePort
---------------------------

Patch the Grafana service to expose it externally using NodePort:

.. code-block:: bash

   kubectl patch svc prometheus-grafana \
     -n prometheus \
     -p '{"spec":{"type":"NodePort"}}'

