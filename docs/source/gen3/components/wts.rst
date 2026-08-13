Workspace Token Service
=======================

WTS issues and manages credentials used by Hatchery-launched workspaces.

Configured values
-----------------

* ``enabled: true`` deploys WTS.
* Image tag ``2025.08`` and ``IfNotPresent`` align it with GEN3.
* PostgreSQL role ``wts_gen3`` is configured for database ``wts_gen3``.
* Database host and port are inherited from ``global.postgres``.

The password must move from plain values into a Secret. WTS also consumes OIDC
configuration and renders an initialization Job for its client configuration.

Resources and verification
--------------------------

The chart creates ``wts-deployment``, Service
``workspace-token-service``, ``wts-dbcreate``, and ``wts-oidc-job``::

   kubectl -n gen3 get deployment wts-deployment
   kubectl -n gen3 get service workspace-token-service
   kubectl -n gen3 get job wts-dbcreate wts-oidc-job
   kubectl -n gen3 logs deployment/wts-deployment --tail=100

