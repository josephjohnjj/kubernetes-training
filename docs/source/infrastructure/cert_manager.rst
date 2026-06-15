Cert Manager
============

Cert Manager is a Kubernetes add-on that automates the management and renewal
of TLS certificates. It integrates with certificate authorities such as
Let's Encrypt and can automatically issue, renew, and manage certificates
for applications running in a Kubernetes cluster.


Install Cert Manager by applying the official release manifest:

.. code-block:: bash

   kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.20.2/cert-manager.yaml

Verification
------------

Verify that the Cert Manager components are running successfully:

.. code-block:: bash

   kubectl get pods -n cert-manager


Check the status of the deployment:

.. code-block:: bash

   kubectl get deployments -n cert-manager

