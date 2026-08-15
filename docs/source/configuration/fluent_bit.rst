Fluent Bit
==========

Purpose
-------

Fluent Bit runs as a DaemonSet, tails Kubernetes container logs on each node,
adds Kubernetes metadata, and forwards matching ``kube.*`` records to
OpenSearch.

Configuration decisions
-----------------------

The Argo CD Application reads
``charts/fluent-bit/fluent-bit-values.yaml``. The output uses the cluster-local
OpenSearch service on port ``9200`` with TLS enabled. Certificate verification
is currently disabled. Output retries are unlimited so a temporary destination
failure does not immediately discard records.

Daily index rotation uses:

.. code-block:: text

   Logstash_Format On
   Logstash_Prefix fluent-bit
   Logstash_DateFormat %Y.%m.%d
   Time_Key @timestamp

This produces indices such as ``fluent-bit-2026.08.15``. Daily indices are
required because OpenSearch ISM deletes whole indices rather than selected
records. They also bound shard sizes and make retention inexpensive.

The chart creates a ServiceMonitor labeled ``release: prometheus`` and installs
its bundled dashboard into the ``prometheus`` namespace. This exposes input and
output rates, processed bytes, retries, errors, and dropped records.

Failure behavior
----------------

When OpenSearch crosses its disk flood-stage watermark it changes affected
indices to ``read_only_allow_delete``. Fluent Bit then logs repeated ``failed to
flush chunk`` warnings and retries with backoff. Restarting Fluent Bit before
repairing the destination can discard in-memory buffered chunks.

Verification
------------

.. code-block:: console

   kubectl get daemonset -n fluentbit
   kubectl logs -n fluentbit -l app.kubernetes.io/name=fluent-bit \
     --all-containers=true --prefix --since=30m

In Grafana Explore, select OpenSearch, use the Lucene ``Logs`` query type, and
query ``*`` over a recent time range.
