Metadata Service
================

Metadata Service stores and serves JSON metadata documents independently of
the graph submission model.

Configured values
-----------------

* ``enabled: true`` deploys Metadata Service.
* Image tag ``2025.08`` pins the runtime release.
* PostgreSQL role ``metadata_gen3`` is configured and the expected database is
  ``metadata_gen3``.
* Host and port come from ``global.postgres``.

The current database password must be migrated out of values. The chart also
renders an aggregate metadata synchronization CronJob using its default chart
configuration because no environment override was set for that schedule.

Resources and verification
--------------------------

::

   kubectl -n gen3 get deployment metadata-deployment
   kubectl -n gen3 get job metadata-dbcreate
   kubectl -n gen3 get cronjob metadata-aggregate-sync
   kubectl -n gen3 logs deployment/metadata-deployment --tail=100

