Hatchery
========

Hatchery launches and manages user workspace pods. The configured workspace is
a tutorial JupyterLab environment.

Configured values
-----------------

* ``enabled: true`` and image tag ``2025.08`` deploy Hatchery.
* Workspace image is
  ``quay.io/cdis/heal-notebooks:combined_tutorials__latest``.
* Workspace limit is 1 CPU and ``2Gi`` memory, with target port 8888.
* Jupyter uses base path ``/lw-workspace/proxy/`` and opens at ``/lab``.
* Token and password prompts are disabled because access is expected to be
  controlled by GEN3.
* Idle shutdown is 5,400 seconds (90 minutes).
* Workspace UID is 1000 and filesystem GID is 100.
* User data and GEN3 configuration mount under ``/home/jovyan``.
* The sidecar is limited to 0.1 CPU and ``256Mi`` memory.

.. warning::

   Both workspace and sidecar images use mutable tags (``latest`` and
   ``master``). Pin immutable tags or digests before claiming a reproducible or
   production deployment. Review the lifecycle shell command before upgrades.

Dependencies and verification
-----------------------------

Hatchery requires RBAC to create workspace pods and WTS to provide workspace
tokens. Verify the controller and launch a test workspace through the GEN3 UI::

   kubectl -n gen3 get deployment hatchery-deployment
   kubectl -n gen3 get serviceaccount hatchery-service-account
   kubectl -n gen3 logs deployment/hatchery-deployment --tail=100

