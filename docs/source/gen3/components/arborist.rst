Arborist
========

Arborist is GEN3's authorization policy service. Other services ask Arborist
whether a user may perform an action on a resource path.

Configured values
-----------------

* ``enabled: true`` deploys the component.
* ``image.tag: 2025.08`` aligns it with the GEN3 release train.
* ``image.pullPolicy: IfNotPresent`` reuses a cached image with the same tag.
* ``postgres.username: arborist_gen3`` selects its application database role.
* The password is configured in values today and must be moved to a Secret.

The database host and port are inherited from ``global.postgres``. With the
chart's naming convention, Arborist uses database ``arborist_gen3``. Because
``global.postgres.dbCreate`` is true, the release renders the
``arborist-dbcreate`` Job before the application starts.

Resources and dependencies
--------------------------

The chart creates ``arborist-deployment``, ``arborist-service``, database
credentials, a database-creation Job, and the
``arborist-rm-expired-access`` CronJob. It requires PostgreSQL and is consumed
by Fence and other authorization-aware GEN3 services.

Verify::

   kubectl -n gen3 get deployment arborist-deployment
   kubectl -n gen3 get job arborist-dbcreate
   kubectl -n gen3 get cronjob arborist-rm-expired-access
   kubectl -n gen3 logs deployment/arborist-deployment --tail=100

