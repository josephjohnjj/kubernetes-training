Trivy Operator Installation (Helm)
===================================

This guide explains how to install Trivy Operator using Helm and how to verify its installation in a Kubernetes cluster.



Add Helm Repository
--------------------

.. code-block:: bash

   helm repo add aqua https://aquasecurity.github.io/helm-charts/
   helm repo update



Install version ``0.33.1`` into the ``trivy-system`` namespace:

.. code-block:: bash

   helm install trivy-operator aqua/trivy-operator \
     --namespace trivy-system \
     --create-namespace \
     --version 0.33.1

Reports
-----------------------------

Check generated vulnerability reports:

.. code-block:: bash

   kubectl get vulnerabilityreports --all-namespaces -o wide



Check generated configuration audit reports:

.. code-block:: bash

   kubectl get configauditreports --all-namespaces -o wide



Inspect logs of the Trivy operator deployment:

.. code-block:: bash

   kubectl logs -n trivy-system deployment/trivy-operator

