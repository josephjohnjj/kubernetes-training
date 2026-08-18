GEN3 Simple Example Data
========================

This directory contains the files used by
``docs/source/gen3/simple_data_example.rst``.

Directory layout::

   raw/
     laboratory_export.csv  Original flat laboratory export
     P001.vcf               Abbreviated raw VCF for participant P001
     P002.vcf               Abbreviated raw VCF for participant P002

   metadata/
     case.tsv
     demographic.tsv
     sample.tsv
     aliquot.tsv
     vcf_file.tsv

   dictionary/
     case.yaml
     demographic.yaml
     sample.yaml
     aliquot.yaml
     vcf_file.yaml

The TSV files contain real tab characters. Submit them in this dependency
order::

   case.tsv
      |-- demographic.tsv
      `-- sample.tsv
             `-- aliquot.tsv
                    `-- vcf_file.tsv

The dictionary YAML files are deliberately abbreviated teaching examples.
They show the domain properties and relationships used by the sample, but are
not a complete buildable GEN3 dictionary. A production dictionary must add
the common schema references, system properties, constraints, and formal link
syntax required by its selected baseline dictionary.

The Indexd GUIDs in ``vcf_file.tsv`` are fictional. Upload the VCF files,
register them in the target environment, and replace ``dg.DEMO/1111`` and
``dg.DEMO/2222`` with the GUIDs returned by that environment before submitting
file-node metadata.

