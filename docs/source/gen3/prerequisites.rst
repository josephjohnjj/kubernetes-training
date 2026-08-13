GEN3 Prerequisites
==================

Complete these prerequisites before bootstrapping GEN3. The commands assume
the repository is cloned locally and ``kubectl`` points to the intended
cluster.

Access and tools
----------------

The operator needs cluster-admin access for the initial installation. Install:

* ``git`` to clone this repository.
* ``kubectl`` compatible with the Kubernetes server.
* ``helm`` version 3.
* ``argocd`` CLI for convenient sync and status checks (optional).
* ``kubectl cnpg`` plugin for PostgreSQL status checks (optional).

Verify the target before changing it::

   kubectl config current-context
   kubectl cluster-info
   kubectl auth can-i create customresourcedefinitions.apiextensions.k8s.io
   kubectl get nodes -o wide

Cluster requirements
--------------------

The deployment requires:

* A healthy Kubernetes cluster with working DNS and a CNI plugin.
* At least three schedulable nodes for CloudNativePG required anti-affinity.
* Three dedicated Ceph nodes named ``storage1``, ``storage2``, and ``storage3``.
* Empty devices ``nvme1n1``, ``nvme2n1``, and ``nvme3n1`` on every Ceph node.
* Network access to the container registries referenced by the charts.
* A route from users to the ingress-nginx NodePort service.
* DNS records, or ``nip.io`` hostnames, resolving to that externally reachable
  address.

.. warning::

   The Ceph manifest claims the nine named devices. Confirm that none contains
   required data or an operating-system filesystem before installing Ceph.

Capacity planning
-----------------

Allow capacity for Ceph replication as well as Kubernetes PVC requests. The
current GEN3 database requests three ``50Gi`` volumes and Elasticsearch
requests one ``100Gi`` volume. Each associated Ceph pool uses three replicas.
Leave additional capacity for Ceph health, recovery, object buckets, logs, and
future volume expansion.

Required namespaces and controllers
-----------------------------------

Argo CD creates most namespaces, but these controllers must become ready before
their custom resources are applied:

* Rook-Ceph operator and Ceph CSI drivers.
* CloudNativePG operator.
* Elastic Cloud on Kubernetes (ECK) operator.
* ingress-nginx controller.

The target namespaces include ``argocd``, ``rook-ceph``, ``cnpg-system``,
``gen3-db``, ``elasticsearch``, ``ingress-nginx``, ``keycloak``, and ``gen3``.

Configuration decisions
-----------------------

Choose and record these values before deployment:

* GEN3 public hostname.
* Keycloak public hostname.
* External address used by ingress-nginx.
* TLS issuer and certificate Secret names, if HTTPS is required.
* Password-generation and secret-management method.
* Backup bucket, retention period, recovery-point objective, and recovery-time
  objective.

Replace the repository's environment-specific ``44.203.188.20.nip.io`` names.
Do not reuse the example passwords or access keys currently present in values
files; rotate them and use the templates in :doc:`secrets`.

Deployment order
----------------

Use this dependency order:

#. Install Argo CD and its ``infrastructure`` AppProject.
#. Deploy Rook-Ceph operator and CSI drivers.
#. Create and verify the Ceph cluster.
#. Create Ceph pools, filesystems, StorageClasses, object store, and buckets.
#. Deploy CloudNativePG and ECK operators.
#. Create safe database Secrets and deploy PostgreSQL and Elasticsearch.
#. Install ingress-nginx.
#. Install and configure Keycloak.
#. Deploy GEN3 and wait for database initialization jobs.
#. Run the PostgreSQL permissions Job only after all service databases exist.
#. Apply ingress rules and perform the end-to-end readiness checks.

Use :doc:`readiness` as the gate between stages.

