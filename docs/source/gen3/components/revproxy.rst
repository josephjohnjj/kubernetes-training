Revproxy
========

Revproxy is GEN3's NGINX-based front door. It exposes one public origin and
routes paths to Portal, Fence, Sheepdog, Guppy, and the other internal services.

Configured values
-----------------

* ``enabled: true`` deploys Revproxy with image tag ``2025.08``.
* Hostname is ``gen3.44.203.188.20.nip.io``.
* Service type is ``ClusterIP`` because ingress-nginx provides external access.
* ``ingress.enabled: false`` currently prevents the chart from rendering the
  public GEN3 Ingress.
* ``ingress.className: nginx`` is already selected for when ingress is enabled.

The hostname is duplicated under ``global.hostname`` and ``revproxy.hostname``;
update both together. Enable the Ingress or apply an equivalent separately
managed rule before expecting public access.

Verify::

   kubectl -n gen3 get deployment revproxy-deployment
   kubectl -n gen3 get service revproxy-service
   kubectl -n gen3 get endpoints revproxy-service
   kubectl -n gen3 logs deployment/revproxy-deployment --tail=100

See :doc:`../nginx_ingress` for the external routing configuration.

