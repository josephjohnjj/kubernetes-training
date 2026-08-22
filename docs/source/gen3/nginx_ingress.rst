NGINX Ingress Rules for GEN3
============================

The repository deploys ingress-nginx chart ``4.15.1`` with controller
``1.15.1``. Its Service type is ``NodePort``.

Install and verify the controller
---------------------------------

Argo CD manages it through ``argocd/infrastructure/networking/01-ingress-nginx.yaml``::

   kubectl -n argocd get application ingress-nginx
   kubectl -n ingress-nginx get deployment,pod,service
   kubectl get ingressclass nginx

Record the assigned HTTP and HTTPS NodePorts::

   kubectl -n ingress-nginx get service ingress-nginx-controller

An external load balancer, firewall rule, or direct node address must forward
ports 80 and 443 to those NodePorts.

GEN3 ingress
------------

The GEN3 chart's Revproxy Ingress is enabled in the current environment values.
For a new environment, replace the host in both ``hostname`` and ``hosts``::

   revproxy:
     hostname: gen3.example.org
     ingress:
       enabled: true
       className: nginx
       annotations:
         cert-manager.io/cluster-issuer: letsencrypt-production
         nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
       hosts:
         - host: gen3.example.org
           paths:
             - path: /
               pathType: Prefix
       tls:
         - secretName: gen3-ingress-tls
           hosts:
             - gen3.example.org

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
     annotations:
       cert-manager.io/cluster-issuer: letsencrypt-production
       nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
   spec:
     ingressClassName: nginx
     tls:
       - hosts:
           - keycloak.example.org
         secretName: keycloak-ingress-tls
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

Issue certificates through cert-manager and add ``spec.tls`` to every public
Ingress resource::

   tls:
     - hosts:
         - gen3.example.org
       secretName: gen3-tls

Use a separate TLS Secret for each hostname. Keycloak uses the trusted
``keycloak-ingress-tls`` Secret, advertises an HTTPS issuer, and performs OIDC
discovery over HTTPS. Redirect URIs must exactly match their public HTTPS
clients.

Verification
------------

::

   kubectl get ingress -A
   kubectl -n ingress-nginx logs deployment/ingress-nginx-controller --tail=100
   curl -I https://gen3.example.org/
   curl -I https://keycloak.example.org/
   curl -I http://keycloak.example.org/

The HTTPS requests must validate without ``-k``. The HTTP request must return
``308 Permanent Redirect`` to the HTTPS Keycloak origin.

A ``404`` from the NGINX default backend normally indicates a hostname or
IngressClass mismatch. A ``502`` or ``503`` normally indicates that the backend
Service has no ready endpoints or the configured service port is wrong.
