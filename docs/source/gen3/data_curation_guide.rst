GEN3 Dictionary, Metadata, and Data Curation Guide
==================================================

This guide introduces the three artifacts involved in loading data into GEN3:

* The **data dictionary** defines the permitted graph nodes, properties, data
  types, controlled values, required fields, and relationships.
* **Metadata submission files** contain records that conform to that
  dictionary. They are normally TSV or JSON files submitted through Sheepdog.
* **Raw data files**, such as VCF, BAM, CSV, and image files, are stored in
  object storage, registered in Indexd, and associated with graph metadata
  through data-file nodes.

These artifacts are related, but they are not interchangeable. A TSV in this
repository has no effect on GEN3 until it is submitted and committed.

What is GEN3?
-------------

GEN3 is a platform for building a data commons: a system that stores research
data, describes it with structured metadata, controls access, and lets users
search for relevant records and files.

A genomic data commons might contain participants, demographic information,
biological samples, DNA aliquots, VCF or BAM files, and information about how
those files were generated. GEN3 divides this information into two broad
groups:

* **Raw data files** are downloadable objects such as VCF, BAM, FASTQ, CSV,
  image, and report files. They are normally stored in S3-compatible object
  storage such as Ceph.
* **Metadata** describes the participants, samples, aliquots, files, and their
  relationships. It includes values such as participant identifiers, sample
  types, file names, checksums, and genome builds.

Metadata provides the fields that users query, filter, and aggregate in the
Portal. The contents of a raw data file are not automatically exposed as
searchable GEN3 properties. Values inside a source file must be curated into
metadata if users need to search them.

Before continuing, see :doc:`nomenclature` for definitions of nodes,
properties, entities, links, cardinality, and aliquots.

Core concepts in one example
----------------------------

The dictionary can define a node type called ``case`` with properties such as
``submitter_id``, ``disease_type``, and ``primary_site``. The repository's
sample TSV supplies one record of that type::

   type  submitter_id  project_id  disease_type  primary_site
   case  poc-case-001  POC-DEMO    Not Reported  Not Reported

The distinction is fundamental:

* The **dictionary** says that ``case`` exists and defines what a valid case
  looks like.
* The **metadata TSV** says that the particular case ``poc-case-001`` exists
  and supplies its property values.
* Sheepdog validates the record against the dictionary before storing it.

In database terms, the dictionary resembles a schema and a submitted metadata
record resembles a row. The GEN3 representation is a graph because records
are connected through explicit links. A small biospecimen graph might be::

   Case: poc-case-001
      |-- Demographic: poc-demographic-001
      `-- Sample: poc-sample-001
             `-- Aliquot: poc-aliquot-001
                    `-- VCF file metadata

Projects and identifiers
------------------------

Every submitted record belongs to a GEN3 project. The sample uses project ID
``POC-DEMO``, which conventionally represents program ``POC`` and project code
``DEMO``. The program and project must exist, and the submitting user must
have permission for that project, before metadata can be loaded.

``submitter_id`` is the stable identifier chosen by the data submitter. Useful
examples are ``poc-case-001``, ``poc-sample-001``, and
``poc-aliquot-001``. A submitter ID should be deterministic, unique in its
project, traceable to the source system, and free from personally identifying
information. GEN3 also generates internal identifiers; submitters should not
substitute those for their own stable source identifiers.

How the GEN3 services participate
---------------------------------

The major components have separate responsibilities:

.. list-table:: GEN3 data-flow components
   :header-rows: 1
   :widths: 20 80

   * - Component
     - Responsibility
   * - Data dictionary
     - Defines valid node types, properties, values, requirements, and links.
   * - Sheepdog
     - Validates metadata submissions and stores graph records in PostgreSQL.
   * - PostgreSQL
     - Holds normalized metadata entities and their relationships.
   * - Object storage
     - Holds the actual downloadable VCF, BAM, image, CSV, and other files.
   * - Indexd
     - Registers stored files, their locations, checksums, sizes, and GUIDs.
   * - Tube
     - Extracts graph metadata and produces flattened search documents.
   * - Elasticsearch
     - Stores the documents used for fast searches and aggregations.
   * - Guppy
     - Provides an authorized GraphQL API over the search indices.
   * - Portal
     - Displays Guppy fields as tables, filters, charts, counts, and manifests.

Successful Sheepdog submission does not guarantee that a record will appear
in the Explorer. Tube must include its node and properties, Elasticsearch must
contain the resulting document, Guppy must expose the index, and the Portal
must request the corresponding fields.

Data flow
---------

The complete flow is conceptually::

   Raw source data
       |
       +-- curate descriptive fields --> metadata TSV files
       |                                      |
       |                                      v
       |                              Sheepdog validation
       |                                      |
       |                                      v
       |                              PostgreSQL graph
       |
       +-- upload and register files --> Indexd GUIDs
                                              |
                                              v
                                  Tube ETL -> Elasticsearch
                                              |
                                              v
                                       Guppy -> Portal

End-to-end workflow
-------------------

A complete implementation proceeds in this order:

#. Understand and profile the source data.
#. Design the graph of domain nodes and relationships.
#. Create or select a compatible data dictionary.
#. Build, version, publish, and configure its ``schema.json``.
#. Configure authorization, then create the program and project.
#. Download TSV templates generated from the installed dictionary.
#. Curate source values into separate, linked node TSV files.
#. Submit parents before children through Sheepdog.
#. Verify that Sheepdog accepted and stored the graph records.
#. Upload raw data files to object storage.
#. Register those files in Indexd and obtain their GUIDs.
#. Submit file-node metadata linked to the appropriate biological or analysis
   records.
#. Configure and run Tube ETL.
#. Verify the resulting Elasticsearch documents and Guppy schema.
#. Configure Portal fields, filters, charts, and file manifests.
#. Test the results as both authorized and unauthorized users.
#. Automate transformation, validation, submission, and verification.

The remaining sections explain the dictionary, metadata, and curation parts
of this workflow in more detail.

Create a data dictionary
------------------------

A GEN3 dictionary is the schema for a commons. Begin with a domain model, for
example::

   Program
      `-- Project
            `-- Case
                  |-- Demographic
                  `-- Sample
                        `-- Aliquot
                              `-- VCF file

The actual node names, link directions, cardinalities, and required
properties must come from the selected dictionary. ``Case`` may instead be
called ``Subject`` in some commons.

For each source field, determine:

* its business meaning and owning node;
* its GEN3 property name and JSON Schema type;
* whether it is required;
* its units and controlled vocabulary;
* whether it changes over time;
* whether it contains identifying or sensitive information; and
* whether it is queryable metadata or content that belongs in a raw file.

Maintain a mapping specification before writing schemas or transformation
code. For example:

.. list-table:: Example source-to-GEN3 mapping
   :header-rows: 1
   :widths: 20 15 20 15 30

   * - Raw field
     - Node
     - Property
     - Type
     - Rule
   * - ``patient_no``
     - ``case``
     - ``submitter_id``
     - string
     - Prefix with ``poc-case-``.
   * - ``diagnosis``
     - ``case``
     - ``disease_type``
     - enum/string
     - Normalize to the permitted vocabulary.
   * - ``body_site``
     - ``case``
     - ``primary_site``
     - enum/string
     - Normalize anatomical terminology.
   * - ``sex``
     - ``demographic``
     - ``gender``
     - enum
     - Map source codes to approved values.
   * - ``birth_year``
     - ``demographic``
     - ``year_of_birth``
     - integer
     - Parse and apply a plausible-range check.
   * - ``vcf_path``
     - ``vcf_file``
     - file properties
     - mixed
     - Upload and register the file separately.

GEN3 dictionaries are normally maintained as one YAML schema per node and
built into a combined ``schema.json``. An abbreviated, conceptual node looks
like this::

   $id: case
   title: Case
   category: administrative
   description: A participant or case in the study.
   type: object
   properties:
     submitter_id:
       type: string
       description: Submitter-assigned identifier for the case.
     disease_type:
       type: string
       enum:
         - Cancer
         - Healthy Control
         - Not Reported
     primary_site:
       type: string
       enum:
         - Blood
         - Lung
         - Not Reported
   required:
     - submitter_id
     - disease_type
     - primary_site

This fragment is not a complete production node. Real nodes normally import
common properties and define links using the conventions of their baseline
dictionary. Start by copying a compatible node from a GEN3 core dictionary
rather than recreating the system fields.

The implementation workflow is:

#. Fork or copy a compatible core dictionary.
#. Add or modify the per-node YAML files.
#. Validate references, links, types, required fields, and enumerations.
#. Build the combined ``schema.json`` using that repository's tooling.
#. Tag and publish the dictionary at an immutable or versioned URL.
#. Set ``global.dictionaryUrl`` to that URL.
#. Align Tube, Guppy, and Portal configuration with the dictionary.

For example::

   global:
     dictionaryUrl: https://example.org/dictionaries/poc/v1.0.0/schema.json

The current deployment instead points to the mutable upstream development
dictionary in ``sample-gen3/gen3/values/gen3-values.yaml``::

   global:
     dictionaryUrl: https://s3.amazonaws.com/dictionary-artifacts/datadictionary/develop/schema.json

Use a pinned dictionary for reproducible environments. Replacing a dictionary
after data has been submitted can require data migration, resubmission, and
ETL changes.

Create metadata submission files
--------------------------------

Metadata is normally divided into one TSV per dictionary node, for example::

   case.tsv
   demographic.tsv
   sample.tsv
   aliquot.tsv
   vcf_file.tsv

Each row creates or updates one graph entity. Obtain templates from the
Dictionary page of the running commons because those templates contain the
exact required fields and link-column names for the installed dictionary.

Case example
~~~~~~~~~~~~

The repository contains ``sample-gen3/test-data/poc-case.tsv``::

   type  submitter_id  project_id  disease_type  primary_site
   case  poc-case-001  POC-DEMO    Not Reported  Not Reported

``type`` selects the ``case`` node. ``submitter_id`` is the submitter-managed,
stable record identifier. ``project_id`` identifies both the data ownership
and authorization scope. By the conventional GEN3 naming scheme,
``POC-DEMO`` represents program ``POC`` and project code ``DEMO``. That
program and project must exist before this row is submitted.

Linked-node example
~~~~~~~~~~~~~~~~~~~

An illustrative demographic TSV is::

   type  submitter_id          project_id  cases.submitter_id  gender  race          ethnicity      year_of_birth
   demographic  poc-demographic-001  POC-DEMO    poc-case-001       Female  Not Reported  Not Reported  1970

The link says that ``poc-demographic-001`` belongs to
``poc-case-001``. The real link header might differ; do not guess whether it is
``case.submitter_id``, ``cases.submitter_id``, or another name. Use the TSV
template produced by the installed dictionary.

Submit parent nodes before their children::

   Program -> Project -> Case -> Demographic
                             `-> Sample -> Aliquot -> Data-file metadata

Submitting a child whose parent does not exist normally results in an
``INVALID_LINK`` validation error. Each submission must also supply all
required properties, exact enumerated values, and a unique ``submitter_id``
within the project.

Curate raw data
---------------

Curation converts source data into consistent, dictionary-valid records. It
should be implemented as a repeatable transformation rather than manual
spreadsheet editing.

1. Profile the source
~~~~~~~~~~~~~~~~~~~~~

Measure record counts, missing-value patterns, duplicate identifiers, data
types, invalid ranges, inconsistent vocabularies, multi-valued cells, and the
presence of sensitive information. Inventory referenced files and calculate
their sizes and checksums.

For example, a raw file might contain::

   patient_no,diagnosis,body_site,sex,birth_year,sample_no
   1,,blood,F,1970,S01

2. Define transformations
~~~~~~~~~~~~~~~~~~~~~~~~~~

Document deterministic rules such as::

   patient_no 1     -> submitter_id poc-case-001
   diagnosis empty  -> disease_type "Not Reported"
   body_site blood  -> primary_site "Blood"
   sex F            -> gender "Female"
   birth_year       -> integer plus range validation
   sample_no S01    -> submitter_id poc-sample-S01

Do not automatically replace every missing value with ``Not Reported``. Use
that value only if the dictionary permits it and it correctly represents the
source. Otherwise omit an optional value or reject the record for review.

3. Split flat rows into graph nodes
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

One source row may produce a case, a demographic, and a sample row. The child
rows must carry dictionary-defined links back to the appropriate parents.
Stable identifiers make the transformation repeatable and allow a resubmission
to update the intended records.

4. Validate before submission
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Check that:

* all required values are populated;
* enums match exactly, including spelling and case;
* identifiers are stable and unique;
* all parent references resolve;
* numeric fields do not contain units or other text;
* date and multi-value formats follow the dictionary;
* tabs and embedded newlines do not corrupt TSV output;
* identifying information is removed or protected as required; and
* repeated transformation produces identical output.

Submit the curated TSVs through the Portal, Sheepdog API, or GEN3 SDK. Inspect
the per-entity validation response and commit the transaction when the chosen
workflow uses a separate commit step.

5. Handle raw files separately
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

For each VCF, BAM, image, or other downloadable file:

#. Calculate its checksum and file size.
#. Upload it to configured object storage.
#. Register it in Indexd to obtain a GUID.
#. Create the appropriate dictionary file-node metadata.
#. Link that record to its sample, aliquot, subject, or analysis.
#. Submit the file-node metadata through Sheepdog.

Typical file metadata includes ``object_id``, ``file_name``, ``file_size``,
``md5sum``, ``data_format``, ``data_type``, ``data_category``, ``project_id``,
and a parent link.

A source CSV may be handled in two ways. Transform its rows into graph metadata
when they must be searchable, or register the unchanged CSV as a data file
when users need to download it. Some datasets require both.

Repository alignment warning
----------------------------

The current sample and the active ETL overlay are not aligned:

* ``sample-gen3/test-data/poc-case.tsv`` submits a ``case`` node.
* ``sample-gen3/gen3/values.d/00-etl-mapping.yaml`` builds ``subject`` and
  ``file`` indices for the 1000 Genomes model.

Consequently, a valid ``case`` can exist in Sheepdog and PostgreSQL without
appearing in the current Explorer. Choose either a case-oriented model and
align Tube, Guppy, and Portal with it, or curate the sample as the ``subject``
and related nodes expected by the 1000 Genomes dictionary and ETL mapping.

Recommended first milestone
---------------------------

#. Pin a versioned dictionary.
#. Create the ``POC`` program and ``DEMO`` project and grant authorization.
#. Download the exact ``case`` or ``subject`` TSV template.
#. Curate and submit one valid root record.
#. Verify it through Sheepdog or PostgreSQL.
#. Align and run Tube ETL.
#. Verify the Elasticsearch index and Guppy schema.
#. Confirm the record appears in the Portal.

See :doc:`data_model` for the repository's intended graph and
:doc:`sample_data_flow` for the existing case record's downstream flow.

External references
-------------------

* `Creating a New Data Dictionary <https://docs.gen3.org/gen3-resources/operator-guide/create-data-dictionary/>`_
* `Submitting Structured Data <https://docs.gen3.org/gen3-resources/operator-guide/submit-structured-data/>`_
* `GEN3 Data Dictionary user guide <https://gen3.org/resources/user/dictionary/>`_
