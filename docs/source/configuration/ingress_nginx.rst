ingress-nginx
=============

Purpose
-------

ingress-nginx supplies Kubernetes ingress routing. Its controller metrics make
request volume, status codes, latency, and connection behavior available to
Prometheus and Grafana.

Configuration decisions
-----------------------

``charts/ingress-nginx/ingress-nginx-values.yaml`` enables the controller
metrics endpoint and ServiceMonitor. The monitor carries
``release: prometheus`` so it matches the cross-namespace Prometheus selector.
The controller is a host-network DaemonSet selected by
``ingress-ready=true``. It binds directly to ports 80 and 443 on every Talos
ingress worker; there is no NodePort Service or HAProxy hop. Public DNS points
to the ingress workers' stable addresses. Port 80 remains reachable for ACME
HTTP-01 validation, but every platform Ingress redirects ordinary HTTP
requests to HTTPS.

Platform HTTPS ingresses
------------------------

Argo CD reconciles the Ingress resources in ``argocd/ingresses`` through the
``platform-ingresses`` Application. Each public component uses a certificate
issued by ``letsencrypt-production`` and stored in a namespace-local TLS
Secret. The annotation
``nginx.ingress.kubernetes.io/force-ssl-redirect: "true"`` returns a permanent
redirect for HTTP requests.

.. list-table:: Public ingress configuration
   :header-rows: 1
   :widths: 20 28 27 25

   * - Component
     - Public HTTPS host
     - TLS Secret
     - NGINX-to-service protocol
   * - Argo CD
     - ``argocd.44.203.188.20.nip.io``
     - ``argocd-ingress-tls``
     - HTTPS, port 443
   * - Ceph Dashboard
     - ``ceph.44.203.188.20.nip.io``
     - ``ceph-dashboard-ingress-tls``
     - HTTP, port 7000
   * - Grafana
     - ``grafana.44.203.188.20.nip.io``
     - ``grafana-ingress-tls``
     - HTTP, port 80
   * - Jaeger
     - ``jaeger.44.203.188.20.nip.io``
     - ``jaeger-ingress-tls``
     - HTTP, port 16686
   * - Keycloak
     - ``keycloak.44.203.188.20.nip.io``
     - ``keycloak-ingress-tls``
     - HTTP, port 80
   * - OpenSearch Dashboards
     - ``opensearch.44.203.188.20.nip.io``
     - ``opensearch-dashboards-ingress-tls``
     - HTTP, port 5601

TLS terminates at ingress-nginx for the HTTP backends. Those cluster-local
hops do not make the public endpoint HTTP. Argo CD is the exception: its
Service already exposes HTTPS, so its Ingress sets
``nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"``. The Ceph manifest
sets the equivalent ``"HTTP"`` value explicitly; HTTP is the controller's
default for the other services.

Certificate resources
---------------------

The same Argo CD Application manages the staging and production
``ClusterIssuer`` resources. Staging is retained for testing new hostnames
without consuming production issuance limits. Public ingresses reference only
``letsencrypt-production`` after staging validation succeeds.

Use this pattern for another public component::

   metadata:
     annotations:
       cert-manager.io/cluster-issuer: letsencrypt-production
       nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
   spec:
     ingressClassName: nginx
     tls:
       - hosts:
           - component.example.org
         secretName: component-ingress-tls

Do not change ``backend-protocol`` to HTTPS unless the selected Service port
actually speaks TLS. Doing so against an HTTP backend normally produces a
``502 Bad Gateway``.

Enabling collection does not install a dedicated ingress dashboard. Metrics
can be queried through Explore or used in a reviewed dashboard.

Verification
------------

Verify Argo CD reconciliation and certificate readiness::

   kubectl -n argocd get application platform-ingresses
   kubectl get certificate -A
   kubectl get clusterissuer letsencrypt-production

Verify a public endpoint and its redirect::

   curl -I https://jaeger.44.203.188.20.nip.io
   curl -I http://jaeger.44.203.188.20.nip.io

The HTTPS request must validate without ``-k``. The HTTP request must return
``308 Permanent Redirect`` with an HTTPS ``Location`` header.

Controller metrics remain available through Prometheus:

.. code-block:: promql

   up{namespace="ingress-nginx"}

Controller metric names commonly begin with
``nginx_ingress_controller_``.
