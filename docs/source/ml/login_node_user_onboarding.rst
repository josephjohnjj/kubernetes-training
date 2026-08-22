Login Node User Onboarding
==========================

Overview
--------

The ML access model separates operating-system access from Kubernetes
authorization:

.. code-block:: text

   Individual SSH key
           |
           v
   Linux account on the login node
           |
           v
   Restricted Kubernetes ServiceAccount
           |
           v
   Kubeflow TrainJob in mlproject

Users are not given ``sudo``, an administrator kubeconfig, direct Pod creation,
Secret access, or RBAC administration. The current implementation uses
Kubernetes ServiceAccounts because the Keycloak endpoint advertises an HTTP
issuer, which cannot be used directly for Kubernetes OIDC authentication.

The examples onboard ``mluser1`` to the login node at ``44.203.188.20``.
Replace these environment-specific values in another deployment.

Repository resources
--------------------

.. list-table::
   :header-rows: 1
   :widths: 48 52

   * - Path
     - Purpose
   * - ``scripts/login-node/01-create-login-user.sh``
     - Creates the Linux account and SSH key pair.
   * - ``scripts/login-node/02-create-user-kubeconfig.sh``
     - Installs a restricted ServiceAccount kubeconfig.
   * - ``argocd/applications/mlprojects/03-job-submitter-role.yaml``
     - Defines shared namespace-scoped submission permissions.
   * - ``argocd/applications/mlprojects/users/mluser1.yaml``
     - Creates the user's ServiceAccount and RoleBinding.

Create the Linux user
---------------------

On the login node, run:

.. code-block:: console

   sudo ./scripts/login-node/01-create-login-user.sh mluser1

The script creates ``/home/mluser1`` with ``/bin/bash``, leaves the user out of
privileged groups, generates a passphrase-protected Ed25519 key pair, installs
the public key in ``authorized_keys``, and creates ``~/.kube`` with mode
``0700``.

The generated key pair is initially stored at:

.. code-block:: text

   /root/login-user-keys/mluser1/id_ed25519
   /root/login-user-keys/mluser1/id_ed25519.pub

The first file is the private key. The ``ssh -i`` option requires that private
key, not the ``.pub`` file.

.. warning::

   Never commit, email, or publish ``id_ed25519``. Treat it as a password. The
   public ``.pub`` file is not secret.

Transfer and test the private key
---------------------------------

Temporarily make the private key available to the existing administrative
account on the login node:

.. code-block:: console

   sudo cp /root/login-user-keys/mluser1/id_ed25519 \
     /home/ubuntu/mluser1-id_ed25519
   sudo chown ubuntu:ubuntu /home/ubuntu/mluser1-id_ed25519
   sudo chmod 0600 /home/ubuntu/mluser1-id_ed25519

Copy it to the administrator workstation:

.. code-block:: console

   scp -i ~/.ssh/terraform-user \
     ubuntu@44.203.188.20:/home/ubuntu/mluser1-id_ed25519 \
     ~/.ssh/mluser1-id_ed25519
   chmod 0600 ~/.ssh/mluser1-id_ed25519

Test the login:

.. code-block:: console

   ssh -i ~/.ssh/mluser1-id_ed25519 mluser1@44.203.188.20

After a successful test, remove the server-side private-key copies:

.. code-block:: console

   sudo rm /home/ubuntu/mluser1-id_ed25519
   sudo rm /root/login-user-keys/mluser1/id_ed25519

The installed public key and root-owned public-key backup may remain. Verify
that the account is unprivileged:

.. code-block:: console

   whoami
   id
   sudo -n true
   ls -ld ~/.ssh ~/.kube

``whoami`` must return ``mluser1``, and ``sudo -n true`` must fail.

Provision Kubernetes authorization through Argo CD
--------------------------------------------------

The shared ``kubeflow-cpu-job-submitter`` Role permits users to create, read,
watch, and delete Kubeflow TrainJobs; read their Pods and logs; and inspect
Kueue LocalQueues and Workloads. It deliberately does not permit direct Pod
creation, Secret access, RBAC changes, queue administration, or access outside
``mlproject``.

The per-user manifest creates:

* ServiceAccount ``mlproject:mluser1``.
* RoleBinding ``mluser1-kubeflow-submitter``.

To onboard another user, create a manifest under
``argocd/applications/mlprojects/users/`` and replace every occurrence of
``mluser1``. Do not duplicate the shared Role.

After committing and pushing, wait for Argo CD and verify the resources:

.. code-block:: console

   kubectl -n mlproject get serviceaccount mluser1
   kubectl -n mlproject get role kubeflow-cpu-job-submitter
   kubectl -n mlproject get rolebinding mluser1-kubeflow-submitter

Verify both allowed and denied operations:

.. code-block:: console

   kubectl auth can-i create trainjobs.trainer.kubeflow.org \
     --as=system:serviceaccount:mlproject:mluser1 -n mlproject
   kubectl auth can-i create pods \
     --as=system:serviceaccount:mlproject:mluser1 -n mlproject
   kubectl auth can-i get secrets \
     --as=system:serviceaccount:mlproject:mluser1 -n mlproject

The expected answers are ``yes``, ``no``, and ``no``.

Install the restricted kubeconfig
---------------------------------

Run the credential script on the login node as ``ubuntu``. Do not run the
complete script with ``sudo``; it uses the current administrator kubeconfig
and elevates only while installing the finished file:

.. code-block:: console

   ./scripts/login-node/02-create-user-kubeconfig.sh mluser1

The script creates the ``mluser1-token`` ServiceAccount token Secret and
installs a mode ``0600`` kubeconfig at ``/home/mluser1/.kube/config``.

.. code-block:: console

   sudo -u mluser1 kubectl auth whoami
   sudo -u mluser1 kubectl auth can-i create trainjobs.trainer.kubeflow.org
   sudo -u mluser1 kubectl auth can-i create pods
   sudo -u mluser1 kubectl auth can-i get secrets

The identity must be ``system:serviceaccount:mlproject:mluser1`` and the
permission answers must be ``yes``, ``no``, and ``no``.

The lab uses a persistent bearer token. Delete ``secret/mluser1-token``
immediately if the kubeconfig is exposed.

.. danger::

   Never copy ``/etc/kubernetes/admin.conf`` or the ``ubuntu`` administrator
   kubeconfig into an ML user's home directory.

Offboarding
-----------

Delete the user's manifest under ``argocd/applications/mlprojects/users/`` and
push the change. Argo CD pruning removes the ServiceAccount and RoleBinding.
Lock or delete the Linux account only after preserving required user data, and
remove remaining SSH keys and Kubernetes credentials.

Next step
---------

Continue with :doc:`kubeflow_job_submission` to enable the runtime, submit a
CPU TrainJob, and monitor its progress through Kueue.
