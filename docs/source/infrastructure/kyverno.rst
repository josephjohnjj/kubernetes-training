Kyverno Helm Installation Guide
===============================


First, add the official Kyverno Helm repository:

.. code-block:: bash

   helm repo add kyverno https://kyverno.github.io/kyverno/
   helm repo update

Install Kyverno Using Helm
--------------------------

Install Kyverno into its own namespace with custom replica settings:

.. code-block:: bash

   helm install kyverno kyverno/kyverno -n kyverno --create-namespace \
     --set admissionController.replicas=3 \
     --set backgroundController.replicas=2 \
     --set cleanupController.replicas=2 \
     --set reportsController.replicas=2

Verify Installation
------------------

Check that the Kyverno pods are running:

.. code-block:: bash

   kubectl get pods -n kyverno

Check the Kyverno services:

.. code-block:: bash

   kubectl get svc -n kyverno

Upgrade Kyverno (Optional)
--------------------------

To update replica counts or upgrade Kyverno later:

.. code-block:: bash

   helm upgrade kyverno kyverno/kyverno -n kyverno \
     --set admissionController.replicas=3 \
     --set backgroundController.replicas=2 \
     --set cleanupController.replicas=2 \
     --set reportsController.replicas=2