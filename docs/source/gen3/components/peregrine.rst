Peregrine
=========

Peregrine exposes graph-oriented query APIs over submitted GEN3 data.

Configured values
-----------------

* ``enabled: true`` deploys Peregrine.
* Image tag ``2025.08`` and ``IfNotPresent`` align it with the release.
* PostgreSQL role ``peregrine_gen3`` is configured; the host and port are
  inherited from the shared CloudNativePG values.
* Its expected database is ``peregrine_gen3``.

The current password value must be replaced with a Kubernetes or external
Secret. Peregrine also depends on the global dictionary and GEN3 authentication
services.

Resources and verification
--------------------------

The chart creates ``peregrine-deployment``, ``peregrine-service``, and
``peregrine-dbcreate``::

   kubectl -n gen3 get deployment peregrine-deployment
   kubectl -n gen3 get job peregrine-dbcreate
   kubectl -n gen3 logs deployment/peregrine-deployment --tail=100

