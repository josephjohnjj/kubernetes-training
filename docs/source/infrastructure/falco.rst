Falco Installation and Upgrade Guide (Helm)
===========================================


First, add the Falco Security Helm repository:

.. code-block:: bash

   helm repo add falcosecurity https://falcosecurity.github.io/charts

Update Helm repositories:

.. code-block:: bash

   helm repo update


Install Falco
--------------

Install Falco in a dedicated namespace using Helm:

.. code-block:: bash

   helm install --replace falco \
     --namespace falco \
     --create-namespace \
     --set tty=true \
     falcosecurity/falco


Verify Installation
-------------------

Check if Falco pods are running:

.. code-block:: bash

   kubectl get pods -n falco


Upgrade Falco with Falcosidekick and Web UI
--------------------------------------------

To enable Falcosidekick and its web UI, upgrade the Helm release:

.. code-block:: bash

   helm upgrade --namespace falco falco falcosecurity/falco \
     --set falcosidekick.enabled=true \
     --set falcosidekick.webui.enabled=true


Post-Upgrade Verification
-------------------------

Confirm updated pods and services:

.. code-block:: bash

   kubectl get pods -n falco
   kubectl get svc -n falco

Notes
-----

- Ensure the `falco` namespace exists or is created by Helm.
- The `--set tty=true` option enables better log readability in container runtime environments.
- Falcosidekick provides event forwarding and integrations, while the Web UI allows visualization of events.