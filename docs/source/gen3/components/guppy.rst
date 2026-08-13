Guppy
=====

Guppy provides GraphQL and aggregation APIs over Elasticsearch for the GEN3
data explorer.

Configured values
-----------------

* ``enabled: true`` overrides the chart default of false.
* Image tag ``2025.08`` pins the release.
* Elasticsearch endpoint uses the in-cluster ECK HTTP service on port 9200.
* Data index is ``dev_case`` with type ``case``.
* Array configuration index is ``dev_case-array-config``.
* Authorization filtering uses field ``auth_resource_path``.
* Encryption whitelist processing is disabled and its list is empty.

.. warning::

   The current endpoint embeds Elasticsearch credentials in the URL. Replace it
   with Secret-backed environment variables or the chart's supported Secret
   mechanism.

Dependencies and verification
-----------------------------

Guppy requires Elasticsearch indices, so the release includes the
``gen3-elasticsearch-bootstrap`` PreSync Job. Tube subsequently replaces or
populates the empty index with submitted data::

   kubectl -n gen3 get deployment guppy-deployment
   kubectl -n gen3 get job gen3-elasticsearch-bootstrap
   kubectl -n gen3 logs deployment/guppy-deployment --tail=100

