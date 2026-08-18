GEN3 Data Lifecycle and Components
==================================

This page explains which GEN3 components participate when data is submitted,
stored, transformed, queried, and downloaded. It follows the example records
from :doc:`simple_data_example`.

GEN3 has more than one data path. Structured metadata is stored as a graph in
PostgreSQL, raw files are stored in object storage and registered in Indexd,
and searchable Explorer documents are derived into Elasticsearch.

Lifecycle overview
------------------

The main paths are::

   Structured metadata submission
   User -> Portal/API -> Revproxy -> Fence/Arborist -> Sheepdog
                                                   -> Dictionary validation
                                                   -> PostgreSQL graph

   Raw file registration and storage
   User -> Fence upload flow -> Indexd record -> Object storage
                                    |
                                    `-> GUID used by Sheepdog file node

   Explorer transformation and query
   PostgreSQL graph -> Tube/Spark -> Elasticsearch -> Guppy -> Portal

   Normalized graph query
   User -> Revproxy -> Fence/Arborist -> Peregrine -> PostgreSQL graph

   File download
   User -> Portal/API -> Fence/Arborist -> Indexd -> signed object URL
                                                    -> Object storage

The exact HTTP routes and enabled services depend on the GEN3 release and
deployment configuration. The diagrams show component responsibilities rather
than every internal request.

Components at a glance
----------------------

.. list-table:: Components in the data lifecycle
   :header-rows: 1
   :widths: 20 30 50

   * - Component
     - Lifecycle stage
     - Responsibility
   * - Portal
     - Submit and query
     - Provides browser interfaces for submission, dictionary viewing,
       exploration, and file discovery.
   * - Revproxy
     - All external stages
     - Presents one external hostname and routes requests to the appropriate
       internal GEN3 service.
   * - Fence
     - Authentication and file access
     - Authenticates users, issues tokens, and participates in controlled file
       upload and download workflows.
   * - Arborist
     - Authorization
     - Determines whether an authenticated identity can perform an action on
       a program, project, service, or data resource.
   * - Data dictionary
     - Metadata validation
     - Defines valid nodes, properties, types, enumerations, requirements, and
       links.
   * - Sheepdog
     - Metadata submission
     - Validates and commits structured metadata into the graph database.
   * - PostgreSQL
     - Metadata storage
     - Stores normalized graph entities, properties, relationships, programs,
       projects, and submission state used by graph services.
   * - Indexd
     - File registration
     - Maps a stable GUID to file locations, hashes, sizes, and related
       registration information.
   * - Object storage
     - Raw file storage
     - Stores the bytes of VCF, BAM, FASTQ, image, CSV, and other files.
   * - Tube
     - ETL
     - Reads graph metadata and converts selected nodes and relationships into
       denormalized search documents.
   * - Spark
     - ETL execution
     - Performs Tube's distributed transformations, joins, flattening, and
       aggregations.
   * - Elasticsearch
     - Search storage
     - Stores denormalized documents for fast filtering and aggregation.
   * - Guppy
     - Explorer queries
     - Provides an authorized GraphQL interface over Elasticsearch.
   * - Peregrine
     - Graph queries
     - Provides GraphQL access to normalized metadata and relationships in
       PostgreSQL.
   * - Audit
     - Operational traceability
     - Records configured security-sensitive or user actions, depending on
       deployment settings.

Stage 1: authenticate and authorize the submitter
-------------------------------------------------

Before GEN3 accepts a submission, it must establish who the submitter is and
what that identity may do.

#. The user signs in through the Portal or obtains an API access token.
#. Fence authenticates the identity using the configured identity provider.
#. Revproxy routes the submission request to the appropriate backend.
#. Arborist evaluates the user's policies for the target program and project.
#. The request continues only if the user has the required create or update
   permission.

For the worked example, project ``DEMO-STUDY1`` must already exist and the user
must have submission permission for a resource path conceptually like::

   /programs/DEMO/projects/STUDY1

Authentication answers **who is this user?** Authorization answers **may this
user submit to this project?** Fence and Arborist cooperate, but those are
different decisions.

Stage 2: submit structured metadata
-----------------------------------

Assume the submitter uploads ``case.tsv`` containing::

   type  submitter_id    project_id  disease_type  primary_site  consent_group
   case  demo-case-P001  DEMO-STUDY1 Cancer        Blood         General Research Use

The metadata path is::

   Portal or SDK
       |
       v
   Revproxy
       |
       +-- authentication/authorization -> Fence and Arborist
       |
       v
   Sheepdog
       |
       +-- schema lookup -> configured data dictionary
       |
       v
   PostgreSQL

Sheepdog checks each entity for:

* a known ``type`` matching a dictionary node;
* required properties;
* valid JSON Schema data types;
* exact controlled-vocabulary values;
* a valid and authorized ``project_id``;
* uniqueness rules involving ``submitter_id``;
* valid parent links; and
* whether the operation creates or updates a record.

The response contains per-record validation results. Depending on the
submission interface and Sheepdog workflow, validation and commit may be
separate operations. A file merely present in this Git repository or displayed
in the Portal has not necessarily been committed.

Stage 3: resolve node links
---------------------------

After the case exists, a sample record can refer to it::

   type    submitter_id     project_id  cases.submitter_id  sample_type
   sample  demo-sample-S001 DEMO-STUDY1 demo-case-P001      Blood

Sheepdog resolves ``cases.submitter_id`` to an existing case in the same
project. If ``demo-case-P001`` is absent, invalid, or inaccessible, the sample
is rejected rather than stored as a disconnected record.

This is why submissions proceed from parent to child::

   case
      |-- demographic
      `-- sample
             `-- aliquot
                    `-- vcf_file

The resulting records and links form the normalized metadata graph.

Stage 4: store normalized metadata
----------------------------------

After validation and commit, Sheepdog writes the metadata to its PostgreSQL
database. Conceptually, the graph now contains::

   case: demo-case-P001
      disease_type = Cancer
      primary_site = Blood
      |
      `-- sample: demo-sample-S001
             sample_type = Blood
             |
             `-- aliquot: demo-aliquot-A001
                    analyte_type = DNA

PostgreSQL stores normalized entities and links. A demographic value remains
on its demographic record rather than being copied into every related record.
This representation preserves the dictionary model and supports relationship
traversal.

The graph database is the authoritative store for submitted structured
metadata. Elasticsearch is a derived search representation and should not be
treated as the submission source of truth.

Stage 5: upload and register raw files
--------------------------------------

The VCF file follows a different path because Sheepdog metadata does not hold
the VCF bytes.

For ``P001.vcf``:

#. Calculate the file size and checksum.
#. Upload the bytes to the configured object-storage bucket.
#. Create an Indexd record containing the URL, checksum, size, and access
   information.
#. Receive a persistent GUID, for example ``dg.DEMO/1111``.
#. Put that GUID in the ``object_id`` property of the ``vcf_file`` metadata
   record.
#. Link the ``vcf_file`` record to ``demo-aliquot-A001`` and submit it through
   Sheepdog.

The same logical file is therefore represented in three places:

.. list-table:: Representations of one raw file
   :header-rows: 1
   :widths: 25 35 40

   * - Location
     - Example
     - Purpose
   * - Object storage
     - The bytes of ``P001.vcf``
     - Durable raw-file storage.
   * - Indexd
     - GUID ``dg.DEMO/1111`` plus URL and hashes
     - Locates and verifies the stored object.
   * - Sheepdog graph
     - ``vcf_file`` entity ``demo-vcf-P001``
     - Describes and links the file to its biological lineage.

An Indexd record without a Sheepdog file node is registered but lacks the
domain relationships needed for graph discovery. A Sheepdog file node with an
invalid or missing Indexd GUID cannot provide a valid downloadable object.

Stage 6: transform metadata for exploration
-------------------------------------------

The normalized graph is flexible but is not the representation used by the
Portal Explorer for fast faceting. Tube creates that representation.

The configured Tube mapping specifies:

* the root node for each output document;
* direct properties copied from the root;
* properties flattened from related nodes;
* parent properties brought into the document;
* relationship counts or other aggregations; and
* the destination Elasticsearch index and document type.

For a case-oriented mapping, Tube and Spark might transform this graph::

   case -> demographic
      `-> sample -> aliquot -> vcf_file

into a document resembling::

   {
     "submitter_id": "demo-case-P001",
     "project_id": "DEMO-STUDY1",
     "disease_type": "Cancer",
     "primary_site": "Blood",
     "gender": "Female",
     "sample_count": 1,
     "aliquot_count": 1,
     "vcf_file_count": 1
   }

This document is an illustrative ETL result, not an upload payload. The exact
fields and count names are determined by the Tube mapping.

Tube may run as a scheduled Kubernetes CronJob or as a manually triggered Job.
Until a successful ETL run processes committed graph data, new records may not
appear in Elasticsearch or the Portal Explorer.

Stage 7: store searchable documents
-----------------------------------

Tube writes the derived documents to Elasticsearch. Elasticsearch provides:

* fast full-field filtering;
* aggregations used for charts and counts;
* denormalized documents suitable for tables; and
* indices optimized for Explorer workloads.

The index may be versioned and exposed through an alias. The configured Guppy
index name must resolve to the index written by Tube. Field names and scalar
versus array types must also agree with Tube's array configuration.

Rebuilding or rotating an Elasticsearch index does not recreate missing
source metadata. The committed Sheepdog/PostgreSQL graph remains the source
from which ETL derives new indices.

Stage 8: query through the Portal Explorer
------------------------------------------

An Explorer query follows this path::

   Browser
      |
      v
   Portal
      |
      v
   Revproxy
      |
      +-- identity and permissions -> Fence/Arborist
      |
      v
   Guppy GraphQL API
      |
      v
   Elasticsearch

The Portal does not normally query Sheepdog directly for Explorer charts.
It sends a GraphQL query to Guppy. Guppy queries the configured Elasticsearch
index and applies authorization filtering so that the user sees only permitted
projects or resources.

For example, the Portal might request cases where::

   disease_type = Cancer
   primary_site = Blood

Guppy converts the GraphQL request into Elasticsearch queries and returns
matching rows and aggregations. The Portal then renders the response as a
table, filter, or chart.

The following names must remain aligned:

.. list-table:: Explorer configuration alignment
   :header-rows: 1
   :widths: 25 35 40

   * - Layer
     - Configuration
     - Required agreement
   * - Dictionary
     - Node and property names
     - Defines the submitted source fields.
   * - Tube
     - Root, paths, properties, and ``doc_type``
     - Selects fields and creates the search document.
   * - Elasticsearch
     - Index and field mappings
     - Must contain the expected documents and types.
   * - Guppy
     - Index, data type, array config, and auth field
     - Must match Tube and Elasticsearch.
   * - Portal
     - Explorer data type, fields, filters, and charts
     - Must request fields exposed by Guppy.

Stage 9: query the normalized graph
-----------------------------------

Not every query should use the flattened Explorer index. Peregrine provides a
GraphQL interface for querying normalized graph metadata and traversing its
relationships.

The graph-query path is::

   Client -> Revproxy -> authentication/authorization -> Peregrine
                                                    -> PostgreSQL graph

Use the graph API when a query depends on the original node relationships or
when verifying submitted graph records. Use Guppy when the query is for fast
Explorer-style filtering, aggregations, and denormalized tables.

These APIs can return different shapes for the same underlying study:

* Peregrine can present a case, its samples, and their aliquots as related
  entities.
* Guppy can present one flattened case document containing selected properties
  and calculated counts.

Stage 10: download a discovered file
------------------------------------

After a user discovers ``P001.vcf`` through the Portal, downloading it involves
the authorization and file-registration services::

   User selects file GUID
       |
       v
   Fence checks identity and requested access
       |
       v
   Arborist checks project/resource permission
       |
       v
   Indexd resolves GUID to object location
       |
       v
   Fence returns a temporary signed URL
       |
       v
   User downloads bytes from object storage

The signed URL is temporary. It allows the object store to serve the file
without exposing permanent storage credentials. Finding file metadata in a
query does not by itself grant permission to download the underlying object.

Stage 11: auditing and operational verification
-----------------------------------------------

Where enabled, Audit records configured security-relevant activities such as
logins or presigned-URL requests. Kubernetes logs and job status provide
additional operational evidence for submission and ETL troubleshooting.

Verify each boundary independently:

.. list-table:: Lifecycle verification
   :header-rows: 1
   :widths: 30 70

   * - Boundary
     - Verification question
   * - Authentication
     - Can the user obtain a valid session or token?
   * - Authorization
     - Does Arborist grant the expected project action?
   * - Dictionary
     - Does the submitted node and every value validate?
   * - Sheepdog/PostgreSQL
     - Was the transaction committed and can the graph record be queried?
   * - Object storage
     - Do the expected object bytes exist at the registered location?
   * - Indexd
     - Does the GUID resolve to the correct size, hash, and URL?
   * - Tube/Spark
     - Did the ETL job finish without mapping or type errors?
   * - Elasticsearch
     - Does the target index contain the expected document?
   * - Guppy
     - Does GraphQL return the document for an authorized user?
   * - Portal
     - Do the expected table row, filters, charts, and file link appear?
   * - Access control
     - Is the same information hidden or denied for an unauthorized user?

Example lifecycle summary
-------------------------

For ``demo-vcf-P001``, the complete lifecycle is::

   1. Curator creates case, sample, and aliquot metadata.
   2. Sheepdog validates them against the dictionary.
   3. Sheepdog stores the committed records and links in PostgreSQL.
   4. The VCF bytes are uploaded to object storage.
   5. Indexd registers the VCF as GUID dg.DEMO/1111.
   6. A vcf_file node links that GUID to demo-aliquot-A001.
   7. Tube reads the graph and creates an Elasticsearch document.
   8. Guppy queries the document and applies authorization filtering.
   9. Portal displays the participant and file metadata.
  10. Fence and Arborist authorize a download request.
  11. Indexd resolves the GUID and Fence issues a signed object URL.
  12. The user downloads P001.vcf from object storage.

The shortest component summary is::

   Dictionary    = what structured metadata is valid
   Sheepdog      = metadata validation and submission
   PostgreSQL    = authoritative normalized metadata graph
   Object store  = raw file bytes
   Indexd        = GUID-to-file registration
   Tube/Spark    = graph-to-search transformation
   Elasticsearch = denormalized search documents
   Guppy         = authorized Explorer GraphQL API
   Peregrine     = normalized graph GraphQL API
   Fence         = authentication and controlled file access
   Arborist      = authorization decisions
   Portal        = user-facing submission, exploration, and discovery
   Revproxy      = external request routing

See :doc:`components` for deployment-specific component pages and
:doc:`sample_data_flow` for the repository's existing proof-of-concept record.

