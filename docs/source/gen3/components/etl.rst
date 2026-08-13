Tube ETL
========

Tube is the GEN3 ETL process. It reads graph data written by Sheepdog and builds
denormalized Elasticsearch documents used by Guppy and Portal.

Configured values
-----------------

* ``enabled: true`` renders ``etl-cronjob``.
* Tube uses ``quay.io/cdis/tube:2025.08``.
* Spark uses ``quay.io/cdis/gen3-spark:2025.08``.
* Elasticsearch endpoint is
  ``elasticsearch-es-http.elasticsearch.svc:9200`` with TLS disabled.
* The Elasticsearch user is ``elastic``; its password must come from a Secret.
* Tube and Spark each request ``300m`` CPU and ``128Mi`` memory.

Mapping
-------

The ``00-etl-mapping.yaml`` overlay creates aggregator index ``dev_case`` with
root node ``case``. Direct fields include submitter ID, project, disease type,
and primary site. Demographic fields are flattened, while sample and aliquot
relationships are stored as counts.

The mapping must stay aligned with Guppy's ``dev_case`` index and the Portal's
explorer field list. The PreSync Elasticsearch bootstrap Job creates
``dev_case`` and ``dev_case-array-config`` if absent so Guppy can start before
the first ETL execution.

Run and verify::

   kubectl -n gen3 create job --from=cronjob/etl-cronjob etl-manual
   kubectl -n gen3 logs job/etl-manual --all-containers --follow
   kubectl -n gen3 get cronjob etl-cronjob

Use a unique manual Job name when repeating the command.

