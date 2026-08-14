GEN3 Deployment in Kubernetes
=============================

This documentation describes the GEN3 2025.08 deployment on Kubernetes,
including its application components, storage, databases, identity integration,
sample data flow, and Argo CD infrastructure management.

.. note::

   OpenAI Codex was used to help inspect the repository and generate, organize,
   and validate portions of this documentation. The deployment owner remains
   responsible for reviewing all commands, manifests, configuration, and
   security-sensitive values before use.

Deployment management
---------------------

Argo CD is the intended source of truth and deployment mechanism. Infrastructure
and GEN3 changes should normally be made in Git, reviewed, committed, and then
reconciled through the corresponding Argo CD Application.

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

GEN3
----

.. toctree::
   :maxdepth: 1
   :titlesonly:

   gen3

Argo CD Infrastructure
----------------------

.. toctree::
   :maxdepth: 1
   :titlesonly:

   argocd
