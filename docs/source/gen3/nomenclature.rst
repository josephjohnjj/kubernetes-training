GEN3 Nomenclature
=================

GEN3 uses graph and data-model terminology to describe how metadata is
defined, submitted, stored, and connected. This page introduces those terms
for readers who are new to GEN3.

GEN3 components
---------------

GEN3 is composed of cooperating services rather than one application. Each
component has a specific responsibility. A record normally passes through
several components between submission and display in the Portal.

Portal
~~~~~~

The **Portal** is the browser-based user interface. Depending on its
configuration, it provides pages for signing in, viewing the data dictionary,
submitting metadata, exploring searchable data, creating file manifests, and
launching analysis workspaces.

The Portal does not store submitted data itself. It calls backend services
such as Sheepdog, Guppy, Peregrine, Fence, and Indexd through Revproxy.

Revproxy
~~~~~~~~

**Revproxy** is the reverse proxy and external routing layer. It exposes one
GEN3 hostname and sends each incoming path to the correct internal service.
For example, submission, authentication, GraphQL, and file-access requests may
all use the same public hostname but be routed to different components.

Revproxy does not define the data model or store research data.

Fence
~~~~~

**Fence** is the authentication and data-access service. It integrates with
the configured identity provider, manages user sessions and tokens, and
participates in controlled raw-file upload and download workflows.

Authentication answers the question: **Who is making this request?** Fence
works with Arborist when a request also needs an authorization decision.

Arborist
~~~~~~~~

**Arborist** is the authorization service. It evaluates policies and decides
whether an authenticated user or service may perform an action on a resource.
Resources can represent programs, projects, services, files, or other
protected areas of the commons.

Authorization answers the question: **Is this identity allowed to perform
this action on this resource?**

Sheepdog
~~~~~~~~

**Sheepdog** is the structured-metadata submission service. It receives TSV
or JSON records, validates them against the configured data dictionary,
checks their project and parent links, and stores valid committed entities in
the PostgreSQL metadata graph.

Sheepdog stores metadata records; it does not store the bytes of raw VCF, BAM,
FASTQ, image, or other data files.

Data dictionary
~~~~~~~~~~~~~~~

The **data dictionary** is the schema used by Sheepdog and other GEN3
components. It defines node types, properties, data types, controlled values,
required fields, and permitted links.

The dictionary describes what valid metadata looks like. It does not contain
the submitted participant, sample, aliquot, or file records.

PostgreSQL
~~~~~~~~~~

**PostgreSQL** provides persistent relational databases for several GEN3
services. In the metadata lifecycle, Sheepdog stores normalized node entities,
properties, and links in PostgreSQL.

The Sheepdog graph is the authoritative representation of submitted structured
metadata. Elasticsearch contains a derived representation optimized for
searching.

Indexd
~~~~~~

**Indexd** is the raw-file registration service. It associates a persistent
globally unique identifier, usually called a GUID, with information such as a
file's storage URL, checksum, size, and access metadata.

Indexd does not normally store the file bytes. It records how GEN3 identifies,
locates, and verifies the object.

Object storage
~~~~~~~~~~~~~~

**Object storage** holds the actual bytes of raw data files such as VCF, BAM,
FASTQ, CSV, and images. A deployment might use Amazon S3, Ceph Object Gateway,
or another S3-compatible service.

A stored object is normally registered in Indexd and described by a file node
in the Sheepdog metadata graph. These three representations serve different
purposes:

* object storage contains the bytes;
* Indexd maps a GUID to the stored object; and
* a Sheepdog file node describes the file and links it to biological or
  analysis metadata.

Tube
~~~~

**Tube** is the GEN3 extract, transform, and load service. It reads normalized
metadata from the graph, follows configured node relationships, and creates
denormalized documents for Elasticsearch.

A Tube mapping determines the root node, properties to copy, relationships to
flatten, values to aggregate, and destination index. Tube output is derived
search data, not a metadata-submission payload.

Spark
~~~~~

**Apache Spark** is the data-processing engine used by Tube. It performs the
joins, graph traversals, flattening, counting, and other transformations
specified by the Tube mapping.

In Kubernetes deployments, Tube and Spark commonly run in an ETL Job or
CronJob.

Elasticsearch
~~~~~~~~~~~~~

**Elasticsearch** stores the denormalized documents produced by Tube. It is
optimized for fast filtering, aggregation, counts, and Explorer tables.

Elasticsearch is not the authoritative store for submitted graph metadata.
Its indices can be recreated from the committed PostgreSQL graph by running
the appropriate ETL process.

Guppy
~~~~~

**Guppy** provides an authorized GraphQL API over Elasticsearch. The Portal
Explorer uses Guppy for filters, charts, counts, tables, and manifest-related
queries.

Guppy's index name, data type, field types, array configuration, and
authorization field must agree with the indices and documents produced by
Tube.

Peregrine
~~~~~~~~~

**Peregrine** provides a GraphQL query interface for the normalized metadata
graph. It is useful when a query needs the original node records and their
relationships.

Peregrine and Guppy serve different query shapes:

* Peregrine queries normalized graph entities and links in PostgreSQL.
* Guppy queries denormalized Explorer documents in Elasticsearch.

Audit
~~~~~

**Audit** records configured security-sensitive or user activities, such as
logins or presigned-URL requests, depending on deployment configuration. It
supports operational traceability but is not the primary store for research
metadata.

Component relationship summary
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The principal component relationships are::

   Metadata submission:
     Portal/API -> Revproxy -> Fence/Arborist -> Sheepdog
                                             -> PostgreSQL graph

   Raw files:
     Fence upload flow -> Object storage + Indexd GUID
                                      `-> Sheepdog file-node metadata

   Explorer query:
     PostgreSQL -> Tube/Spark -> Elasticsearch -> Guppy -> Portal

   Graph query:
     PostgreSQL -> Peregrine -> Portal/API client

   File download:
     Portal/API -> Fence/Arborist -> Indexd -> signed object-storage URL

See :doc:`data_lifecycle_components` for a step-by-step explanation of how
these components participate when data is submitted, stored, queried, and
downloaded.

Node
----

A **node** is a type of object in the GEN3 data model. Examples include:

* ``case``: a participant, patient, or other unit of investigation;
* ``demographic``: demographic information about a case;
* ``sample``: a biological sample;
* ``aliquot``: a portion extracted from a sample; and
* ``vcf_file``: metadata describing a genomic data file.

Each node groups together properties that describe one kind of thing. For
example, a ``case`` node might have properties named ``submitter_id``,
``disease_type``, and ``primary_site``.

Database analogy
~~~~~~~~~~~~~~~~

It can be helpful to compare GEN3 concepts with a relational database:

.. list-table:: GEN3 and relational database concepts
   :header-rows: 1
   :widths: 40 60

   * - GEN3 concept
     - Database analogy
   * - Node type
     - Table definition
   * - Property
     - Column
   * - Node record or entity
     - Row
   * - Link
     - Relationship between rows in different tables

This is only an analogy. GEN3 presents submitted metadata as a graph in which
node records are connected through explicitly defined links.

Node type and node record
~~~~~~~~~~~~~~~~~~~~~~~~~

The **node type** is the definition in the data dictionary. It specifies the
node's properties, allowed values, required fields, and links. It is defined
once and used to validate every submitted record of that type.

A **node record**, also called an **entity**, is one individual instance of a
node type. For example, the dictionary defines the ``case`` node type, while
``poc-case-001`` is one record of that type.

The repository's ``sample-gen3/test-data/poc-case.tsv`` contains this record::

   type  submitter_id  project_id  disease_type  primary_site
   case  poc-case-001  POC-DEMO    Not Reported  Not Reported

In this row:

* ``case`` tells Sheepdog which dictionary node definition to use;
* ``poc-case-001`` identifies this particular case record;
* ``disease_type`` and ``primary_site`` are properties of the record; and
* ``POC-DEMO`` places the record in a GEN3 project and authorization scope.

Submitting this row does not define the ``case`` node. The node must already
exist in the configured data dictionary. Sheepdog validates the row against
that definition before storing it.

Properties
~~~~~~~~~~

A **property** is a named value describing a node record. A dictionary defines
the property's data type, description, whether it is required, and any
permitted values or validation rules.

For example, ``primary_site`` is a property of the sample case record and its
value is ``Not Reported``. If the dictionary restricts ``primary_site`` to an
enumeration, the submitted value must match one of the permitted values
exactly.

Links and the metadata graph
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

A **link** connects one node record to another. Links turn separate metadata
records into a graph. For example::

   Case: poc-case-001
      |-- Demographic: poc-demographic-001
      `-- Sample: poc-sample-001
             `-- Aliquot: poc-aliquot-001
                    `-- VCF file: poc-vcf-001

The dictionary defines which links are permitted, their direction, and their
cardinality. **Cardinality** describes how many records may participate in a
relationship. For example, one case may have many samples, and one sample may
have many aliquots.

Metadata TSV files represent links through dictionary-defined columns such as
``cases.submitter_id``. The exact column name must be taken from the template
generated by the installed dictionary.

Why GEN3 uses separate nodes
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Nodes should represent meaningful domain concepts, not simply reproduce the
layout of an input spreadsheet. Demographic properties belong on a
``demographic`` node rather than being duplicated on every ``sample`` record.

Separating concepts into linked nodes:

* reduces duplicated metadata;
* makes relationships explicit;
* allows different relationships and validation rules for each concept; and
* lets GEN3 traverse from a case to its demographics, samples, aliquots, and
  data files.

In one sentence, a node is a dictionary-defined type of entity whose
individual records and relationships form the GEN3 metadata graph.

Aliquot
-------

An **aliquot** is a measured portion taken from a larger biological sample.
For example, a blood sample collected from a participant may be divided into
several smaller tubes. Each tube is an aliquot that can be stored, distributed,
or used in a different laboratory process.

The distinction is generally:

* a **sample** represents the source biological material collected from a
  participant, such as blood, tissue, saliva, or plasma; and
* an **aliquot** represents a portion derived from that sample and prepared
  for storage, testing, sequencing, or another analysis.

For example::

   Case: poc-case-001
      `-- Sample: poc-blood-sample-001
             |-- Aliquot: poc-dna-aliquot-001 -> whole-genome sequencing
             `-- Aliquot: poc-dna-aliquot-002 -> validation assay

The exact scientific meaning depends on the commons and its dictionary. Some
data models use an aliquot specifically for extracted analyte, such as DNA or
RNA, while others use additional nodes such as ``portion``, ``analyte``, or
``read_group`` between the sample and data file. Always follow the definitions
and links in the installed dictionary.

Aliquot node and physical aliquot
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

An aliquot node is metadata describing the physical aliquot; it is not the
biological material itself. A GEN3 aliquot record may contain properties such
as:

* a stable ``submitter_id`` or laboratory aliquot identifier;
* the analyte or material type;
* amount, volume, or concentration and their units;
* preparation or extraction method;
* creation or processing information; and
* quality measurements.

Only properties defined by the configured dictionary may be submitted. The
exact property names, units, required fields, and permitted values vary by
dictionary.

An illustrative TSV record could look like this::

   type     submitter_id          project_id  samples.submitter_id  analyte_type
   aliquot  poc-dna-aliquot-001   POC-DEMO    poc-blood-sample-001  DNA

In this example, ``samples.submitter_id`` links the aliquot to the sample from
which it was derived. This link requires the parent sample to exist before the
aliquot is submitted. The actual link header must be obtained from the
dictionary-generated TSV template.

Aliquots and data files
~~~~~~~~~~~~~~~~~~~~~~~

An aliquot often connects the physical biospecimen lineage to generated data
files. For example::

   Case -> Sample -> Aliquot -> Sequencing process -> VCF or BAM file

This lineage helps answer questions such as:

* Which participant and sample produced this data file?
* Were two assays performed on the same aliquot or on different aliquots?
* Which preparation method or analyte produced the sequencing results?

The raw VCF, BAM, or image remains in object storage. The aliquot and file
nodes contain queryable metadata and links; they do not contain the raw file's
contents.

See :doc:`data_curation_guide` for instructions on designing a dictionary and
turning raw source data into node-based metadata submissions.
