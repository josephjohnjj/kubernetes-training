Keycloak Deployment
===================

This section describes the deployment of Keycloak on Kubernetes using
the Bitnami Helm chart.

Storage Configuration
---------------------

Create the storage pool used by Keycloak persistent volumes.

.. code-block:: bash

   kubectl create -f keycloak-pool.yaml

Create a dedicated StorageClass for Keycloak.

.. code-block:: bash

   kubectl create -f keycloak-sc.yaml

Temporarily set the Keycloak StorageClass as the cluster default.

.. code-block:: bash

   kubectl patch storageclass keycloak-sc \
     -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

This ensures that any PersistentVolumeClaims created during the Keycloak
installation automatically use ``keycloak-sc``.

Keycloak Installation
---------------------

Add the Bitnami Helm repository.

.. code-block:: bash

   helm repo add bitnami https://charts.bitnami.com/bitnami

Verify that the repository was added successfully.

.. code-block:: bash

   helm search repo bitnami

Install Keycloak using the Bitnami Helm chart.

.. code-block:: bash

   helm install keycloak bitnami/keycloak --values values.yaml -n keycloak


Verify the deployment:

.. code-block:: bash

   kubectl get pods -n keycloak



Convert the Keycloak service to a ``NodePort`` service.

.. code-block:: bash

   kubectl patch svc keycloak -n keycloak -p '{"spec": {"type": "NodePort"}}'

This makes Keycloak accessible from outside the Kubernetes cluster
through a node IP and allocated port.

Verify the service configuration:

.. code-block:: bash

   kubectl get svc -n keycloak



Display the Kubernetes secret created during installation.

.. code-block:: bash

   kubectl describe secret keycloak -n keycloak

The secret contains the administrator username and password generated
by the Helm chart.

Restore StorageClass Configuration
----------------------------------

After Keycloak has been deployed, remove the default annotation from the
StorageClass.

.. code-block:: bash

   kubectl patch storageclass keycloak-sc -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'

This prevents future workloads from automatically using ``keycloak-sc``.

