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

Keycloak installation through Argo CD
-------------------------------------

The exact Bitnami chart version ``25.2.0`` is vendored under
``charts/keycloak``. Environment overrides are in
``charts/keycloak/keycloak-values.yaml``. The child Application at
``argocd/infrastructure/identity/keycloak/01-keycloak.yaml`` renders that
local chart with Helm release name ``keycloak`` and deploys it to namespace
``keycloak``.

The values reference existing Secrets rather than storing credentials in Git:

* ``keycloak`` with key ``admin-password`` for the administrator password.
* ``keycloak-externaldb`` with key ``db-password`` for the external database.

.. warning::

   A new installation must create both Secrets before the first Keycloak sync.
   The chart intentionally does not generate them. Without them, the
   StatefulSet is created but its Pod remains in ``CreateContainerConfigError``.
   The value in ``keycloak-externaldb`` must exactly match the password assigned
   to PostgreSQL role ``keycloak``; an arbitrary password causes database
   authentication failures.

Prefer External Secrets, SOPS, Sealed Secrets, or another approved declarative
secret workflow. For a manual bootstrap, create the namespace and Secrets
before synchronizing the Application::

   kubectl create namespace keycloak --dry-run=client -o yaml | kubectl apply -f -
   kubectl -n keycloak create secret generic keycloak \
     --from-literal=admin-password='<generated-admin-password>'
   kubectl -n keycloak create secret generic keycloak-externaldb \
     --from-literal=db-password='<password-assigned-to-keycloak-db-role>'

During migration from the existing Helm release, do not replace the live
credentials. Verify that both existing Secrets are present and preserve them
unchanged::

   kubectl -n keycloak get secret keycloak keycloak-externaldb

The Application intentionally has no automated sync policy for its initial
adoption. Commit and push the Application, refresh the parent infrastructure
Application, inspect the diff, and manually sync Keycloak only after confirming
that Argo will retain the existing StatefulSet, Services, and Secrets::

   kubectl -n argocd annotate application infrastructure \
     argocd.argoproj.io/refresh=hard --overwrite
   kubectl -n argocd get application keycloak

After the first sync, verify the deployment:

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


Display Secret metadata without printing its values:

.. code-block:: bash

   kubectl describe secret keycloak -n keycloak

Do not run ``helm upgrade`` after adoption. Argo CD is the workload owner; the
Ansible workflow now prepares only the legacy Keycloak storage resources.

Restore StorageClass Configuration
----------------------------------

After Keycloak has been deployed, remove the default annotation from the
StorageClass.

.. code-block:: bash

   kubectl patch storageclass keycloak-sc -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'

This prevents future workloads from automatically using ``keycloak-sc``.
