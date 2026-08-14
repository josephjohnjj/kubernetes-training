GEN3 Proof-of-Concept Data Model
================================

This page records the current proof-of-concept data model and the intended
end-to-end model. The repository does not yet contain a complete, versioned
dictionary or sample records for every node. Consequently, this document
distinguishes verified configuration from the model that still needs to be
implemented.

Current status
--------------

The implemented sample contains one ``case`` record. The Tube mapping and
Portal configuration additionally expect demographics, samples, and aliquots,
but corresponding sample records are not present.

.. list-table::
   :header-rows: 1
   :widths: 25 25 25 25

   * - Node or concept
     - Sample data
     - Tube mapping
     - Portal usage
   * - Case
     - Present
     - Present
     - Present
   * - Demographic
     - Missing
     - Flattened into case
     - Filters and table fields
   * - Sample
     - Missing
     - Counted from case
     - Dashboard count
   * - Aliquot
     - Missing
     - Counted through samples
     - Dashboard count
   * - Program and project
     - Not defined in test-data files
     - ``project_id`` copied
     - Authorization and project filter

Current sample model
--------------------

The only repository test record is::

   type  submitter_id  project_id  disease_type  primary_site
   case  poc-case-001  POC-DEMO    Not Reported  Not Reported

This produces the smallest useful graph conceptually represented as::

   Program/Project: POC-DEMO
              |
              v
   Case: poc-case-001
      disease_type = Not Reported
      primary_site = Not Reported

The project is referenced by the sample, but the repository does not include
the program/project creation payload or authorization setup needed to recreate
it.

Intended graph model
--------------------

The Tube paths imply this intended graph:

::

   Program
      |
      v
   Project
      |
      v
   Case ----------------> Demographic
      |
      v
   Sample
      |
      v
   Aliquot

The exact relationship names, directions, required properties, and category
definitions must come from the selected GEN3 dictionary. This diagram records
the traversal expected by the current ETL mapping; it is not a replacement for
a versioned dictionary schema.

Node definitions
----------------

Program and project
~~~~~~~~~~~~~~~~~~~

Program and project establish data ownership and authorization scope.
``project_id`` flows into Elasticsearch and is also Guppy's configured
accessible validation field. Before case submission, ``POC-DEMO`` must exist
and the submitting user must have appropriate permissions for its resource
path.

The repository still needs:

* A documented program code and project code.
* The exact project identifier format expected by the dictionary.
* Program/project creation commands or payloads.
* Arborist policy and Fence UserSync entries granting access.

Case
~~~~

Case is the root of the explorer index. Current direct properties are:

* ``submitter_id``
* ``project_id``
* ``disease_type``
* ``primary_site``

Tube creates one ``dev_case`` Elasticsearch document per case. Portal exposes
all four properties in its case table and uses the last three for project,
disease, and site exploration.

Demographic
~~~~~~~~~~~

The ETL mapping follows ``demographics`` from the case and flattens:

* ``gender``
* ``race``
* ``ethnicity``
* ``year_of_birth``

Portal uses gender, race, and ethnicity but does not currently display
``year_of_birth``. No demographic TSV exists, so these indexed fields are
currently absent.

Sample
~~~~~~

The mapping traverses ``samples`` from each case and calculates
``_samples_count``. No individual sample properties are included in the
``dev_case`` document, and no sample TSV exists.

Aliquot
~~~~~~~

The mapping traverses ``samples.aliquots`` and calculates
``_aliquots_count``. No aliquot properties are copied into the case document,
and no aliquot TSV exists.

Relational and indexed representations
--------------------------------------

GEN3 represents the same logical model differently at each layer:

.. list-table::
   :header-rows: 1
   :widths: 25 35 40

   * - Layer
     - Representation
     - Purpose
   * - Dictionary
     - Node and relationship schema
     - Defines valid properties, links, types, and requirements.
   * - Sheepdog/PostgreSQL
     - Normalized graph records
     - Stores submitted nodes and their relationships.
   * - Tube
     - ETL traversal rules
     - Selects, flattens, and aggregates graph properties.
   * - Elasticsearch
     - Denormalized ``dev_case`` documents
     - Supports fast filtering and aggregations.
   * - Guppy
     - Authorized GraphQL ``case`` API
     - Exposes indexed fields and aggregate queries.
   * - Portal
     - Explorer charts, filters, and table definitions
     - Presents Guppy data to users.

Expected case document
----------------------

Once all related records exist, one logical ``dev_case`` document should
contain fields similar to::

   {
     "submitter_id": "poc-case-001",
     "project_id": "POC-DEMO",
     "disease_type": "Not Reported",
     "primary_site": "Not Reported",
     "gender": "REPLACE_WITH_TEST_VALUE",
     "race": "REPLACE_WITH_TEST_VALUE",
     "ethnicity": "REPLACE_WITH_TEST_VALUE",
     "year_of_birth": 1970,
     "_samples_count": 1,
     "_aliquots_count": 1
   }

This is an expected ETL result, not a submission payload. Demographic fields
originate on the related demographic node, while counts are calculated from
relationships.

Minimum complete test dataset
-----------------------------

A minimal end-to-end dataset should contain:

#. One program and one project.
#. One case assigned to that project.
#. One demographic record linked to the case.
#. One sample linked to the case.
#. One aliquot linked to the sample.
#. Fence and Arborist authorization for the test user and project.

Use deterministic submitter IDs, for example::

   project:      POC-DEMO
   case:         poc-case-001
   demographic:  poc-demographic-001
   sample:       poc-sample-001
   aliquot:      poc-aliquot-001

Actual TSV headers and link fields must be generated from the chosen dictionary
rather than copied from this conceptual example.

Missing artifacts
-----------------

The following artifacts are required before the data model is reproducible:

* A repository-owned dictionary URL pinned by version or immutable digest.
* The dictionary source files used to build that schema.
* Program and project creation payloads.
* Demographic, sample, and aliquot TSV files.
* A deterministic submission and commit script.
* Authorization configuration for the sample project.
* Expected PostgreSQL, Elasticsearch, and Guppy results.
* Automated assertions for Portal-visible fields and counts.

Count-field alignment
---------------------

Tube writes per-case relationship fields named ``_samples_count`` and
``_aliquots_count``. Portal dashboard configuration requests GraphQL fields
``_sample_count`` and ``_aliquot_count``. These may be global Guppy node counts
rather than fields in the case document, but they must be checked against the
running Guppy GraphQL schema.

Do not rename either side until the actual GraphQL response is captured. Record
whether each count is global, per project, or per case.

Completion criteria
-------------------

The proof-of-concept data model is complete when:

* Every sample node validates against a pinned dictionary.
* The entire dataset can be submitted to a clean environment using documented
  commands.
* PostgreSQL contains every node and relationship.
* Tube completes without mapping errors.
* ``dev_case`` contains the expected flattened fields and counts.
* Guppy returns those fields for an authorized user and filters them for an
  unauthorized user.
* Portal displays the expected row, charts, filters, and dashboard counts.
* An automated test compares actual results with version-controlled expected
  output.

See :doc:`sample_data_flow` for the detailed flow of the existing case-only
record.

