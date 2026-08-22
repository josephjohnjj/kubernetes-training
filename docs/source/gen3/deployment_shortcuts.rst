GEN3 Deployment Shortcuts and Risks
===================================

This deployment was created as a proof of concept and includes shortcuts that
must be addressed before it is used for sensitive data or as a production
service. This page summarizes the known risks and the recommended order of
remediation.

Critical security risks
-----------------------

Credentials are stored directly in YAML files. These include PostgreSQL,
Elasticsearch, Ceph object storage, and Keycloak OIDC credentials. Some
passwords are also embedded in connection URLs and environment variables,
where they may appear in rendered manifests, logs, error messages, or process
information.

Credentials committed to Git must be considered exposed even after they are
deleted from the current files, because earlier values remain in Git history.
Rotate all exposed credentials and replace plaintext values with External
Secrets, SOPS, Sealed Secrets, or an equivalent secret-management mechanism.

The public Argo CD, Ceph Dashboard, Grafana, Jaeger, Keycloak, and OpenSearch
Dashboards endpoints use trusted HTTPS certificates and redirect HTTP to
HTTPS. Keycloak advertises an HTTPS issuer, and OIDC discovery uses HTTPS.
Internal PostgreSQL, Elasticsearch, Ceph object-gateway, and selected
service-to-service connections may still be unencrypted; use encrypted
internal connections where supported.

NetworkPolicies are disabled, so workloads are not restricted to only the
services they require. This increases the impact of a compromised pod,
especially while internal traffic is unencrypted. Introduce default-deny
policies followed by explicit DNS, database, Elasticsearch, object storage,
identity-provider, ingress, and monitoring rules.

Access-control risks
--------------------

``tierAccessLevel`` is set to ``libre``. This is appropriate only for the
public sample dataset; controlled or sensitive data requires a reviewed GEN3
authorization model.

The Argo CD ``infrastructure`` project permits all cluster-scoped and
namespace-scoped resource kinds. Compromise of Argo CD or the repository could
therefore modify RBAC, admission webhooks, CRDs, storage, and other cluster-wide
resources. Separate application and infrastructure projects and replace the
wildcard permissions with explicit allowlists.

CloudNativePG enables superuser access, and the GEN3 database owner receives
``CREATEDB`` and ``CREATEROLE``. Reduce these privileges after confirming the
minimum permissions required by database initialization and upgrades.

Supply-chain and versioning risks
---------------------------------

The GEN3 Argo CD application follows ``HEAD`` and most infrastructure
applications follow ``main`` while automated synchronization, pruning, and
self-healing are enabled. A pushed change can therefore be applied directly to
the cluster. Production applications should use promoted Git tags or commit
SHAs.

The primary GEN3 images use the ``2025.08`` tag, but Hatchery defaults still
reference ``master`` and ``latest`` images. Image tags can also be replaced in
a registry. Pin every deployed image by digest and record the digest during
release promotion.

The data dictionary points to ``develop/schema.json``, which can change
independently of this deployment. Use a versioned dictionary artifact tested
with the selected GEN3 release.

Reliability and recovery risks
------------------------------

CloudNativePG runs three instances, but its object-store backup configuration
is commented out. Replication improves availability but does not protect
against accidental deletion, corruption, or loss of the cluster. Configure
off-cluster backups, WAL archiving, retention, monitoring, and regularly tested
restores.

Elasticsearch defaults to a single-node, single-replica deployment. If those
defaults are active, loss of the pod or its volume interrupts search and ETL.
Use a supported multi-node topology or document and test how the index will be
rebuilt from its authoritative data source.

Most GEN3 services do not have environment-specific CPU and memory requests
and limits. Tube and Spark have requests but no limits. Add measured resource
settings, PodDisruptionBudgets where multiple replicas exist, topology spread
or anti-affinity rules, and capacity alerts.

CloudNativePG debug logging is enabled. Return it to the normal production log
level after troubleshooting to reduce noise and the chance of exposing
operational details.

Exposure and reproducibility risks
----------------------------------

The Ceph Dashboard is exposed through a trusted HTTPS ingress with an
authenticated application login. For a production administrative endpoint,
also restrict network access through a VPN, source allowlist, or private
ingress; use a temporary ``kubectl port-forward`` when public access is not
required.

The public hostnames use ``nip.io`` and contain a fixed public IP. A public IP
change will break DNS names, OIDC discovery, and redirect URLs. Use managed DNS
with a stable load-balancer address.

The Ceph cluster manifest hardcodes the nodes ``storage1`` through ``storage3``
and the devices ``nvme1n1`` through ``nvme3n1``. Recreating the deployment
requires exactly that naming and disk layout. Parameterize or clearly validate
these assumptions before applying the manifest; selecting the wrong device can
destroy data.

Remediation priority
--------------------

#. Rotate every exposed credential and remove plaintext secrets from Git and,
   where required, its history.
#. Extend the established cert-manager HTTPS pattern to any additional public
   endpoint, including GEN3 where its environment-specific ingress requires it.
#. Configure and test PostgreSQL backups and recovery.
#. Enable workload isolation with reviewed NetworkPolicies.
#. Pin Argo CD revisions, container images, charts, and the data dictionary to
   immutable versions.
#. Reduce Argo CD, Kubernetes, and PostgreSQL privileges.
#. Remove unnecessary NodePort exposure and replace the fixed ``nip.io`` names.
#. Add high-availability, resource, monitoring, and disaster-recovery controls.

.. warning::

   Do not load sensitive or regulated data until the credential, transport
   security, authorization, backup, and network-isolation items have been
   completed and tested.
