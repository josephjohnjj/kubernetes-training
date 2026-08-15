OpenSearch
==========

Purpose
-------

OpenSearch is the persistent log store queried by Grafana. It runs three
StatefulSet replicas and exposes an HTTPS service in the ``opensearch``
namespace.

Configuration decisions
-----------------------

The Argo CD Application reads ``charts/opensearch/opensearch-values.yaml``.
Persistent volumes use the Rook Ceph ``opensearch-sc`` StorageClass, which
supports volume expansion.

A PostSync Job declared through ``extraObjects`` creates the
``fluent-bit-retention`` Index State Management policy. It matches
``fluent-bit-*`` and permanently deletes indices after 14 days. The Job waits
for cluster health, applies the policy through the cluster-local HTTPS API, and
is removed after succeeding.

The historical index named exactly ``fluent-bit`` does not match this policy.
Retaining or deleting it requires a separate, explicitly approved operation.

Capacity decision
-----------------

The original 8 GiB claims proved insufficient. Two nodes reached 94 percent
utilization, triggered the flood-stage watermark, and stopped ingestion.
Existing PVCs must be expanded before clearing the write block. Changing a
StatefulSet volume claim template does not reliably resize existing claims, so
live PVC expansion and Git-managed defaults must be planned separately.

Do not disable disk watermarks instead of adding capacity or enforcing
retention. That risks filesystem exhaustion and cluster instability.

Verification
------------

.. code-block:: console

   kubectl exec -n opensearch opensearch-cluster-master-0 -- \
     curl -ksS -u 'admin:<password>' \
     'https://localhost:9200/_cat/allocation?v'

   kubectl exec -n opensearch opensearch-cluster-master-0 -- \
     curl -ksS -u 'admin:<password>' \
     'https://localhost:9200/_cat/indices/fluent-bit*?v'

   kubectl exec -n opensearch opensearch-cluster-master-0 -- \
     curl -ksS -u 'admin:<password>' \
     'https://localhost:9200/_plugins/_ism/policies/fluent-bit-retention?pretty'
