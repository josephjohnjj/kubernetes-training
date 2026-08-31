Cert Manager
============

cert-manager is a Kubernetes add-on that automates the management and renewal
of TLS certificates. It integrates with certificate authorities such as
Let's Encrypt and can automatically issue, renew, and manage certificates
for applications running in a Kubernetes cluster. In this environment Argo CD
installs cert-manager from ``argocd/infrastructure/cert-manager/01-cert-manager.yaml``
with its CRDs enabled.

The platform ingresses use two ACME ``ClusterIssuer`` resources in
``argocd/ingresses``:

* ``letsencrypt-staging`` validates a new hostname and ingress path without
  consuming production issuance limits. Its certificates are not trusted by
  browsers.
* ``letsencrypt-production`` issues the trusted certificates used by every
  public platform ingress.

Both issuers use the ingress-nginx HTTP-01 solver. Public DNS must resolve to
the Talos ingress-worker addresses, and port 80 must reach the host-network
ingress-nginx controllers for challenges even though normal HTTP traffic is
redirected to HTTPS.


For a non-Argo bootstrap, install the same pinned cert-manager release by
applying the official manifest:

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

Verify issuers and all certificates::

   kubectl get clusterissuer
   kubectl get certificate,certificaterequest,order,challenge -A

A production certificate is complete when its ``Certificate`` reports
``READY=True``, its ACME ``Order`` is ``valid``, and the named
``kubernetes.io/tls`` Secret exists in the Ingress namespace.
