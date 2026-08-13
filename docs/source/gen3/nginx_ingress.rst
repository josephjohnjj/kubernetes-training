NGINX Ingress Rules for GEN3
============================

The repository deploys ingress-nginx chart ``4.15.1`` with controller
``1.15.1``. Its Service type is ``NodePort``.

Install and verify the controller
---------------------------------

Argo CD manages it through ``argocd/infrastructure/networking/ingress-nginx.yaml``::

   kubectl -n argocd get application ingress-nginx
   kubectl -n ingress-nginx get deployment,pod,service
   kubectl get ingressclass nginx

Record the assigned HTTP and HTTPS NodePorts::

   kubectl -n ingress-nginx get service ingress-nginx-controller

An external load balancer, firewall rule, or direct node address must forward
ports 80 and 443 to those NodePorts.

GEN3 ingress
------------

The GEN3 chart's Revproxy Ingress is currently disabled in environment values.
Enable it and use the deployment hostname::

   revproxy:
     hostname: gen3.example.org
     ingress:
       enabled: true
       className: nginx

The resulting rule sends all GEN3 paths to ``revproxy-service``. Render it
before committing::

   helm template gen3 charts/gen3-2025.08 \
     --namespace gen3 \
     -f charts/gen3-2025.08/values/gen3-values.yaml \
     -f charts/gen3-2025.08/values.d/00-etl-mapping.yaml \
     -f charts/gen3-2025.08/values.d/01-usersync.yaml \
     -f charts/gen3-2025.08/values.d/02-portal-gitops-css.yaml \
     -f charts/gen3-2025.08/values.d/03-portal-gitops-json.yaml \
     --show-only charts/revproxy/templates/ingress_default.yaml

Keycloak ingress
----------------

The current manifest routes the Keycloak hostname to Service ``keycloak`` on
port 80::

   apiVersion: networking.k8s.io/v1
   kind: Ingress
   metadata:
     name: keycloak
     namespace: keycloak
   spec:
     ingressClassName: nginx
     rules:
       - host: keycloak.example.org
         http:
           paths:
             - path: /
               pathType: Prefix
               backend:
                 service:
                   name: keycloak
                   port:
                     number: 80

TLS
---

For production, issue certificates through cert-manager and add ``spec.tls``
to both Ingress resources::

   tls:
     - hosts:
         - gen3.example.org
       secretName: gen3-tls

Use a separate ``keycloak-tls`` Secret for the Keycloak hostname. Update all
OIDC URLs to HTTPS at the same time to avoid issuer and redirect mismatches.

Verification
------------

::

   kubectl get ingress -A
   kubectl -n ingress-nginx logs deployment/ingress-nginx-controller --tail=100
   curl -I -H 'Host: gen3.example.org' http://EXTERNAL_ADDRESS/
   curl -I -H 'Host: keycloak.example.org' http://EXTERNAL_ADDRESS/

A ``404`` from the NGINX default backend normally indicates a hostname or
IngressClass mismatch. A ``502`` or ``503`` normally indicates that the backend
Service has no ready endpoints or the configured service port is wrong.

