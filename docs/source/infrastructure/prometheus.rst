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

Expose Grafana through HTTPS ingress
------------------------------------

Keep the Grafana Service private. Argo CD manages
``argocd/ingresses/03-grafana-ingress.yaml``, which requests the trusted
``grafana-ingress-tls`` certificate and redirects HTTP to HTTPS:

.. code-block:: bash

   kubectl -n prometheus get service prometheus-grafana
   kubectl -n prometheus get ingress grafana
   kubectl -n prometheus get certificate grafana-ingress-tls
   curl -I https://grafana.44.203.188.20.nip.io

The public request terminates TLS at ingress-nginx, which forwards to the
Grafana ClusterIP Service on port 80.
