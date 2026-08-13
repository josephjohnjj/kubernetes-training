Sheepdog
========

Sheepdog is the data-submission service. It validates submitted records against
the configured GEN3 dictionary and stores graph data in PostgreSQL.

Configured values
-----------------

* ``enabled: true`` deploys Sheepdog.
* Image tag ``2025.08`` pins the application release.
* ``pullPolicy: IfNotPresent`` avoids unnecessary pulls for an existing tag.
* PostgreSQL role ``gen3db`` is used for the ``sheepdog_gen3`` database.
* The data dictionary is inherited from ``global.dictionaryUrl`` and currently
  points to the upstream development dictionary schema.

The role has broader graph-management responsibilities than the other service
roles. Its password must not remain in values. Sheepdog initializes its graph
tables and transaction-log structures during startup/database setup.

Data path
---------

Submitted JSON goes through Revproxy to Sheepdog, is authorized through Fence
and Arborist, and is stored in PostgreSQL. Tube later reads this graph data and
writes the explorer index to Elasticsearch.

Verify::

   kubectl -n gen3 get deployment sheepdog-deployment
   kubectl -n gen3 get job sheepdog-dbcreate
   kubectl -n gen3 logs deployment/sheepdog-deployment --all-containers --tail=100

