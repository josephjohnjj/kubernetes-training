Keycloak Deployment
===================

This section describes the deployment of Keycloak on Kubernetes using
the Bitnami Helm chart.

Storage Configuration
---------------------

Create the storage pool used by Keycloak persistent volumes.

.. code-block:: bash

   kubectl create -f manifests/keycloak/01-keycloak-pool.yaml

Create a dedicated StorageClass for Keycloak.

.. code-block:: bash

   kubectl create -f manifests/keycloak/02-keycloak-sc.yaml

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

   helm install keycloak bitnami/keycloak \
     --version 25.2.0 \
     --values manifests/keycloak/03-keycloak-values.yaml \
     -n keycloak


Verify the deployment:

.. code-block:: bash

   kubectl get pods -n keycloak



Keep the Keycloak Service private and confirm that it remains ``ClusterIP``:

.. code-block:: bash

   kubectl -n keycloak get service keycloak

The values set ``proxyHeaders: xforwarded`` so Keycloak trusts the original
HTTPS scheme forwarded by ingress-nginx. Argo CD manages the public Ingress in
``argocd/ingresses/05-keycloak-ingress.yaml``. It requests the
``keycloak-ingress-tls`` certificate from ``letsencrypt-production`` and
redirects HTTP to HTTPS.

Verify the Ingress, certificate, redirect, and advertised issuer:

.. code-block:: bash

   kubectl -n keycloak get ingress keycloak
   kubectl -n keycloak get certificate keycloak-ingress-tls
   curl -I http://keycloak.44.203.188.20.nip.io
   curl -I https://keycloak.44.203.188.20.nip.io
   curl -fsS \
     https://keycloak.44.203.188.20.nip.io/realms/infrastructure/.well-known/openid-configuration

The HTTP request must redirect to HTTPS, and the discovery document must
advertise an HTTPS issuer and HTTPS protocol endpoints. See
:doc:`../configuration/ingress_nginx` for the complete platform ingress
matrix.


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
