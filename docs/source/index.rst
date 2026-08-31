Kubernetes Platform Engineering and Workloads
=============================================

This repository documents the design, deployment, and operation of a
GitOps-managed Kubernetes platform. It covers the cluster foundation and the
workloads that run on it; GEN3 is an important application deployment, but it
is not the only purpose of the repository.

The platform includes:

* AWS, Terraform, Ansible, and Kubernetes cluster provisioning.
* Argo CD application-of-applications management and repository ownership.
* Rook-Ceph storage, CloudNativePG databases, ingress, and Keycloak identity.
* Prometheus, Grafana, Fluent Bit, OpenSearch, and Jaeger observability.
* Kyverno, Trivy, Falco, namespace isolation, and Kubernetes RBAC.
* Kueue and Kubeflow Trainer for HPC-style ML job submission.
* Small LLM inference workloads used to exercise platform capabilities.
* GEN3 2025.08 services, data flows, and operational procedures.

Documentation is organized by platform layer and workload type. Start with the
cluster and GitOps sections when building the environment, use the
configuration sections when operating shared services, and then follow the ML,
LLM, or GEN3 guides for the workload being deployed.

.. note::

   OpenAI Codex was used to help inspect the repository and generate, organize,
   and validate portions of this documentation. The deployment owner remains
   responsible for reviewing all commands, manifests, configuration, and
   security-sensitive values before use.

GitOps and deployment management
--------------------------------

Argo CD is the intended source of truth and deployment mechanism. Platform and
application changes should normally be made in Git, reviewed, committed, and
then reconciled through the corresponding Argo CD Application.

The repository also contains historical and operational material used during
manual installation:

* ``commands.md`` records commands that were run manually during installation
  and configuration.
* ``manifests`` contains Kubernetes manifests used for manual installation and
  one-time configuration.

.. warning::

   Use ``commands.md`` and files under ``manifests`` with extreme caution. They
   may contain environment-specific hostnames, mutable upstream references,
   obsolete configuration, plaintext credentials, or resources now owned by
   Argo CD. Do not run them as a bulk installation procedure. Prefer the Argo CD
   Applications and Git-managed sources, inspect the live diff, and verify the
   exact target cluster before applying any manual command or manifest.

Build the cluster
-----------------

Provision the AWS infrastructure and Kubernetes nodes before bootstrapping the
GitOps-managed platform.

.. toctree::
   :maxdepth: 1
   :titlesonly:

   aws/aws_cluster
   aws/manual_kubernetes_cluster
   talos


Platform architecture and GitOps
--------------------------------

These sections describe the platform components, Argo CD hierarchy, sync
ordering, and ownership boundaries.

.. toctree::
   :maxdepth: 1
   :titlesonly:

   argocd
   Platform infrastructure <infrastructure>

Shared platform configuration
-----------------------------

Use these guides for observability, ingress, workflow scheduling, policy, and
security configuration shared by multiple workloads.

.. toctree::
   :maxdepth: 1
   :titlesonly:

   configuration/index

ML and test inference workloads
-------------------------------

The ML documentation describes an HPC-style login-node workflow in which
restricted users submit Kubeflow TrainJobs through Kueue. The LLM section
contains small inference deployments used to validate compute and persistent
storage.

.. toctree::
   :maxdepth: 1
   :titlesonly:

   ml/index
   llm

GEN3 application platform
-------------------------

GEN3 is one workload suite hosted by the platform. This section documents its
2025.08 deployment, supporting databases and storage, identity integration,
data model, data lifecycle, and readiness checks.

.. toctree::
   :maxdepth: 1
   :titlesonly:

   gen3


External references
-------------------

.. toctree::
   :maxdepth: 1
   :titlesonly:

   references
