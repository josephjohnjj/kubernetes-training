Grafana
=======

Purpose
-------

Grafana is the cluster's common visualization and exploration interface. It
does not store telemetry. It queries Prometheus for metrics, OpenSearch for
logs, and Jaeger for traces.

Configuration decisions
-----------------------

Grafana is deployed as part of ``kube-prometheus-stack`` in the ``prometheus``
namespace. Its overrides are in
``charts/prometheus-stack/prometheus-stack-values.yaml``.

The ``grafana-opensearch-datasource`` plugin is installed through the Grafana
chart. Its data source uses proxy access to
``https://opensearch-cluster-master.opensearch.svc.cluster.local:9200``, matches
``fluent-bit*``, and uses ``@timestamp`` as its time field. The configured
OpenSearch flavor and version are ``opensearch`` and ``3.7.0``.

The Jaeger data source uses proxy access to
``http://jaeger.jaeger.svc.cluster.local:16686``. Cluster DNS names avoid
exposing either backend solely for Grafana. Prometheus and Alertmanager are
provisioned by ``kube-prometheus-stack``.

Security considerations
-----------------------

The OpenSearch password is currently embedded in Git under ``secureJsonData``.
That hides it in the Grafana API after provisioning, but does not encrypt it in
Git or the generated Kubernetes resources. It should move to a Kubernetes
Secret or external secret manager.

``tlsSkipVerify`` is enabled because Grafana does not currently trust the
internally issued OpenSearch certificate. Production deployments should mount
the issuing CA and enable certificate verification.

Verification
------------

Open **Connections > Data sources** and confirm that Prometheus, Alertmanager,
OpenSearch, and Jaeger are present. In Explore, select OpenSearch, choose the
Lucene ``Logs`` query type, and query ``*``. Jaeger remains empty until a trace
producer sends spans.
