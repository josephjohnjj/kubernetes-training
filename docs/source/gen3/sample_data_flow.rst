GEN3 Sample Data Flow
=====================

This page explains how the proof-of-concept case record is intended to move
from a tab-separated input file into PostgreSQL, Elasticsearch, Guppy, and the
Portal explorer.

Flow overview
-------------

::

   poc-case.tsv
        |
        v
   Sheepdog submission API
        |
        v
   PostgreSQL graph: case node
        |
        v
   Tube ETL mapping
        |
        v
   Elasticsearch: dev_case
        |
        v
   Guppy: data type case
        |
        v
   Portal: Cases explorer

The sample record
-----------------

The input file is ``sample-gen3/test-data/poc-case.tsv``::

   type  submitter_id  project_id  disease_type  primary_site
   case  poc-case-001  POC-DEMO    Not Reported  Not Reported

It contains one record of node type ``case``.

.. list-table::
   :header-rows: 1
   :widths: 25 25 50

   * - Column
     - Sample value
     - Meaning
   * - ``type``
     - ``case``
     - Selects the ``case`` node definition in the GEN3 dictionary.
   * - ``submitter_id``
     - ``poc-case-001``
     - Human-assigned identifier for this case within its project.
   * - ``project_id``
     - ``POC-DEMO``
     - Associates the case with its GEN3 program/project and authorization
       scope.
   * - ``disease_type``
     - ``Not Reported``
     - Disease classification displayed and filtered by the explorer.
   * - ``primary_site``
     - ``Not Reported``
     - Primary anatomical site displayed and filtered by the explorer.

The first ``type`` column controls submission but is not copied into the index
as a normal property. Tube assigns the Elasticsearch document type through
``doc_type: case`` instead.

Dictionary validation
---------------------

Sheepdog validates the row against the dictionary configured at
``global.dictionaryUrl``. The current deployment uses the upstream development
dictionary::

   https://s3.amazonaws.com/dictionary-artifacts/datadictionary/develop/schema.json

For the submission to succeed:

* The dictionary must define node ``case`` and the four supplied properties.
* ``POC-DEMO`` must identify an existing GEN3 project.
* The authenticated user must have submission permission for that project.
* Required dictionary properties not present in the TSV must either be
  optional or supplied by the submission process.

The repository contains the TSV, but it does not currently automate its
submission. The file has no effect on a deployment until an authorized client
submits it through Sheepdog and the submission is committed.

PostgreSQL graph
----------------

After successful validation and commit, Sheepdog stores the case as a graph
node in the ``sheepdog_gen3`` PostgreSQL database. At this stage the four values
remain graph properties associated with the case record.

The sample contains no demographic, sample, or aliquot rows. Therefore it does
not create relationships along these paths::

   case -> demographic
   case -> sample -> aliquot

Tube mapping
------------

The mapping is defined in
``charts/gen3-2025.08/values.d/00-etl-mapping.yaml``. Its important settings
are::

   name: dev_case
   doc_type: case
   type: aggregator
   root: case

``root: case`` tells Tube to create one Elasticsearch document for each case
node. The four direct properties are copied without renaming::

   props:
     - name: submitter_id
     - name: project_id
     - name: disease_type
     - name: primary_site

For the sample row, the resulting logical document is approximately::

   {
     "submitter_id": "poc-case-001",
     "project_id": "POC-DEMO",
     "disease_type": "Not Reported",
     "primary_site": "Not Reported"
   }

Tube also attempts to flatten demographic properties and calculate sample and
aliquot counts. Because this sample has no related records, demographic values
will be absent and the relationship counts should be zero.

Elasticsearch index
-------------------

Tube writes the document to Elasticsearch index ``dev_case``. The Argo CD
PreSync Job may create this index and ``dev_case-array-config`` before Tube
runs, but that Job creates only empty indices. It does not load the TSV or
populate case documents.

The sequence must therefore be:

#. Submit and commit the case through Sheepdog.
#. Start or wait for the ``etl-cronjob`` Tube job.
#. Confirm the Tube job succeeds.
#. Confirm ``dev_case`` contains the case document.

Guppy mapping
-------------

Guppy is configured with::

   indices:
     - index: dev_case
       type: case
   configIndex: dev_case-array-config

The index name matches the Tube mapping exactly. Guppy presents the
``dev_case`` documents as GraphQL data type ``case`` and applies authorization
filtering through ``auth_resource_path``.

Portal mapping
--------------

The Portal overlay defines one explorer tab with Guppy data type ``case``. Its
charts, filters, table, and display labels use the same four direct properties.

.. list-table::
   :header-rows: 1
   :widths: 20 20 20 20 20

   * - TSV
     - Tube
     - Elasticsearch
     - Guppy
     - Portal
   * - ``submitter_id``
     - direct property
     - ``submitter_id``
     - case field
     - Case ID table column
   * - ``project_id``
     - direct property
     - ``project_id``
     - case field and authorization check
     - Project chart, filter, and table column
   * - ``disease_type``
     - direct property
     - ``disease_type``
     - case field
     - Disease Type chart, filter, and table column
   * - ``primary_site``
     - direct property
     - ``primary_site``
     - case field
     - Primary Site chart, filter, and table column

This is the core alignment: all four names are preserved from the submitted
case through Tube and Guppy to Portal. No translation layer or field alias is
required.

Additional Portal fields
------------------------

Portal also requests ``gender``, ``race``, and ``ethnicity``. Tube can obtain
these from a linked ``demographics`` node, but the current sample TSV does not
create one. These fields will remain empty until related demographic test data
is added and submitted.

Portal dashboard configuration also requests global case, sample, and aliquot
counts. The exact GraphQL count field names should be checked against the
running Guppy schema; the current Portal singular names and Tube's plural
relationship-count properties are not the same fields.

Verification
------------

Confirm that the ETL Job completed::

   kubectl -n gen3 get jobs
   kubectl -n gen3 logs job/<etl-job-name> --all-containers

Query Elasticsearch from a controlled administrative pod without putting its
password in shell history::

   curl -sS http://elasticsearch-es-http.elasticsearch.svc:9200/dev_case/_count
   curl -sS http://elasticsearch-es-http.elasticsearch.svc:9200/dev_case/_search

The protected ECK endpoint requires authentication in this deployment; obtain
it through the mounted Secret rather than embedding it in the command.

Finally, verify Guppy's GraphQL schema and open the Portal ``Cases`` explorer.
The expected table row is ``poc-case-001`` in project ``POC-DEMO`` with disease
and primary site displayed as ``Not Reported``.

