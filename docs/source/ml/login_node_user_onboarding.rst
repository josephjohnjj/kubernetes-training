Login Node User Onboarding
==========================

Overview
--------

The initial ML user-access model separates operating-system access from
Kubernetes authorization:

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
           |
           v
   Kueue cpu-normal-queue

Users are not given ``sudo``, the Kubernetes administrator kubeconfig, direct
Pod creation, Secret access, or RBAC administration. The current implementation
uses Kubernetes ServiceAccounts because the Keycloak endpoint advertises an
HTTP issuer, which cannot be used directly for Kubernetes OIDC authentication.

The examples below onboard ``mluser1`` to the login node at
``44.203.188.20``. Replace these environment-specific values when deploying a
different cluster.

Repository resources
--------------------

The onboarding workflow uses these Git-managed files:

.. list-table::
   :header-rows: 1
   :widths: 45 55

   * - Path
     - Purpose
   * - ``scripts/login-node/01-create-login-user.sh``
     - Creates the Linux account and SSH key pair on the login node.
   * - ``argocd/applications/mlprojects/03-job-submitter-role.yaml``
     - Defines the shared, namespace-scoped job-submission permissions.
   * - ``argocd/applications/mlprojects/users/mluser1.yaml``
     - Creates the ``mluser1`` ServiceAccount and RoleBinding.
   * - ``argocd/applications/mlprojects/01-namespace.yaml``
     - Creates the ``mlproject`` namespace.
   * - ``kueue/02-cpu-queue.yaml``
     - Defines ``cpu-normal-queue`` and its backing ClusterQueue.

1. Create the Linux user
------------------------

Clone or update the repository on the login node, then run:

.. code-block:: console

   sudo ./scripts/login-node/01-create-login-user.sh mluser1

The script performs the following operations:

#. Creates ``/home/mluser1`` with ``/bin/bash`` as the login shell.
#. Leaves the user outside all privileged groups.
#. Generates a passphrase-protected Ed25519 key pair.
#. Installs the public key in
   ``/home/mluser1/.ssh/authorized_keys``.
#. Creates an empty, mode ``0700`` ``/home/mluser1/.kube`` directory.

The generated key pair is initially stored at:

.. code-block:: text

   /root/login-user-keys/mluser1/id_ed25519
   /root/login-user-keys/mluser1/id_ed25519.pub

The first file is the private key. The second is the public key. The
``ssh -i`` option requires the private key, not the file ending in ``.pub``.

.. warning::

   Never commit, email, paste into a ticket, or otherwise publish
   ``id_ed25519``. Treat it as a password. The public ``.pub`` file is not
   secret.

2. Transfer the private key
---------------------------

On the login node, copy the private key temporarily to the existing
administrative account and restrict its permissions:

.. code-block:: console

   sudo cp \
     /root/login-user-keys/mluser1/id_ed25519 \
     /home/ubuntu/mluser1-id_ed25519
   sudo chown ubuntu:ubuntu /home/ubuntu/mluser1-id_ed25519
   sudo chmod 0600 /home/ubuntu/mluser1-id_ed25519

On the administrator workstation, transfer the file through SSH:

.. code-block:: console

   scp \
     -i ~/.ssh/terraform-user \
     ubuntu@44.203.188.20:/home/ubuntu/mluser1-id_ed25519 \
     ~/.ssh/mluser1-id_ed25519
   chmod 0600 ~/.ssh/mluser1-id_ed25519

Test the new login:

.. code-block:: console

   ssh -i ~/.ssh/mluser1-id_ed25519 mluser1@44.203.188.20

After a successful test, remove both server-side copies of the private key:

.. code-block:: console

   sudo rm /home/ubuntu/mluser1-id_ed25519
   sudo rm /root/login-user-keys/mluser1/id_ed25519

The installed public key and the root-owned public-key backup may remain.

Verify the Linux account
~~~~~~~~~~~~~~~~~~~~~~~~

While connected as ``mluser1``, run:

.. code-block:: console

   whoami
   id
   sudo -n true
   ls -ld ~/.ssh ~/.kube

``whoami`` must return ``mluser1``. The user must not be in the ``sudo`` group,
and ``sudo -n true`` must fail.

3. Provision Kubernetes authorization with Argo CD
--------------------------------------------------

The Argo CD ``applications`` Application recursively reconciles
``argocd/applications``. Consequently, the ML access manifests become active
after they are committed and pushed to the tracked branch.

Shared Role
~~~~~~~~~~~

``argocd/applications/mlprojects/03-job-submitter-role.yaml`` defines
``kubeflow-cpu-job-submitter`` in ``mlproject``. The Role permits:

* Creating, reading, watching, and deleting Kubeflow ``TrainJob`` resources.
* Reading Pods, Pod logs, and events produced by training workloads.
* Reading Kueue ``LocalQueue`` and ``Workload`` resources.

The Role deliberately does not permit:

* Direct Pod creation.
* Reading or changing Secrets.
* Creating ServiceAccounts, Roles, or RoleBindings.
* Modifying Kueue queues or cluster quotas.
* Access outside ``mlproject``.

Per-user resources
~~~~~~~~~~~~~~~~~~

``argocd/applications/mlprojects/users/mluser1.yaml`` creates:

* ServiceAccount ``mlproject:mluser1``.
* RoleBinding ``mluser1-kubeflow-submitter``.

The RoleBinding grants the shared ``kubeflow-cpu-job-submitter`` Role to that
ServiceAccount. To onboard another user, create another file in the same
directory and replace every occurrence of ``mluser1`` with the new username.
Do not duplicate the shared Role.

Commit and push the resources, then wait for Argo CD to report the
``applications`` Application as ``Synced`` and ``Healthy``.

Verify the synchronized resources with the administrator kubeconfig:

.. code-block:: console

   kubectl -n mlproject get serviceaccount mluser1
   kubectl -n mlproject get role kubeflow-cpu-job-submitter
   kubectl -n mlproject get rolebinding mluser1-kubeflow-submitter

Verify the allowed operation:

.. code-block:: console

   kubectl auth can-i create trainjobs.trainer.kubeflow.org \
     --as=system:serviceaccount:mlproject:mluser1 \
     --namespace=mlproject

The expected answer is ``yes``.

Verify that direct Pods and Secrets remain unavailable:

.. code-block:: console

   kubectl auth can-i create pods \
     --as=system:serviceaccount:mlproject:mluser1 \
     --namespace=mlproject

   kubectl auth can-i get secrets \
     --as=system:serviceaccount:mlproject:mluser1 \
     --namespace=mlproject

Both commands must return ``no``.

4. Install restricted Kubernetes credentials
--------------------------------------------

The ServiceAccount does not automatically place a kubeconfig in the Linux
account. After Argo CD creates the user resources, run the credential script on
the login node as ``ubuntu``. Do not invoke the complete script with ``sudo``;
it uses the current administrator kubeconfig and requests ``sudo`` only to
install the completed file:

.. code-block:: console

   ./scripts/login-node/02-create-user-kubeconfig.sh mluser1

The script creates the ``mluser1-token`` ServiceAccount token Secret, builds a
kubeconfig using the current cluster endpoint and CA, and installs it with mode
``0600`` at:

.. code-block:: text

   /home/mluser1/.kube/config

Verify the identity and effective permissions:

.. code-block:: console

   sudo -u mluser1 kubectl auth whoami
   sudo -u mluser1 kubectl auth can-i create trainjobs.trainer.kubeflow.org
   sudo -u mluser1 kubectl auth can-i create pods
   sudo -u mluser1 kubectl auth can-i get secrets

The identity must be
``system:serviceaccount:mlproject:mluser1``. The expected permission answers
are ``yes``, ``no``, and ``no``.

This is a persistent bearer token for the current lab environment. Delete
``secret/mluser1-token`` immediately if the kubeconfig is exposed.

.. danger::

   Never copy ``/etc/kubernetes/admin.conf`` or
   ``/home/ubuntu/.kube/config`` into an ML user home directory. Those files
   grant administrative access and bypass the restricted Role.

5. Enable the Kubeflow training runtime
---------------------------------------

The CPU test uses the optional cluster-scoped ``torch-distributed`` runtime.
The ``kubeflow-trainer`` Argo CD Application enables only this runtime through
the following Helm override:

.. code-block:: yaml

   helm:
     valuesObject:
       runtimes:
         torchDistributed:
           enabled: true

After the parent ``infrastructure`` Application and the ``kubeflow-trainer``
child Application synchronize, verify the runtime from a control node:

.. code-block:: console

   kubectl get clustertrainingruntime torch-distributed

If the child Application has not received the override, hard-refresh both
Argo CD layers:

.. code-block:: console

   kubectl -n argocd annotate application infrastructure \
     argocd.argoproj.io/refresh=hard --overwrite
   kubectl -n argocd annotate application kubeflow-trainer \
     argocd.argoproj.io/refresh=hard --overwrite

The child Application should list ``ClusterTrainingRuntime/torch-distributed``
as a desired resource before job submission.

6. Submit the CPU smoke test
----------------------------

Every user-submitted ``TrainJob`` must be created in ``mlproject`` and select
the CPU LocalQueue:

.. code-block:: yaml

   metadata:
     namespace: mlproject
     labels:
       kueue.x-k8s.io/queue-name: cpu-normal-queue

The repository contains a manually submitted smoke test at
``ml/trainjobs/01-cpu-smoke-test.yaml``. This path is outside Argo CD's managed
directories, so committing the example does not run it automatically.

Submit it on the login node using the restricted user identity:

.. code-block:: console

   cd ~/kubernetes-training
   sudo -u mluser1 kubectl create \
     -f ml/trainjobs/01-cpu-smoke-test.yaml

Kubeflow Trainer manages the training workload, while Kueue holds it until CPU
and memory quota are available.

7. Monitor from the login node
------------------------------

Use ``sudo -u mluser1`` when an administrator is testing the user workflow from
the login node. These commands use ``/home/mluser1/.kube/config``:

.. code-block:: console

   sudo -u mluser1 kubectl get trainjob cpu-smoke-test
   sudo -u mluser1 kubectl get workloads
   sudo -u mluser1 kubectl get pods --watch

Kueue creates a ``Workload`` and initially suspends the TrainJob. After quota
is reserved, the Workload reports ``ADMITTED=True`` and Kueue changes the
TrainJob suspension field to ``false``:

.. code-block:: console

   sudo -u mluser1 kubectl get trainjob cpu-smoke-test \
     -o jsonpath='suspend={.spec.suspend}{"\n"}'

After a Pod appears, follow its output:

.. code-block:: console

   POD=$(sudo -u mluser1 kubectl get pods \
     -o jsonpath='{.items[0].metadata.name}')
   sudo -u mluser1 kubectl logs "$POD" --follow

The first Pod can remain in ``ContainerCreating`` for several minutes while
the CPU worker downloads the large PyTorch image.

8. Monitor from a control node
------------------------------

The Linux account ``mluser1`` exists only on the login node. A command such as
``sudo -u mluser1`` therefore fails on ``control1``. Administrators monitor the
same workload from a control node using the administrator kubeconfig and an
explicit namespace:

.. code-block:: console

   kubectl -n mlproject get trainjob cpu-smoke-test
   kubectl -n mlproject get workloads
   kubectl -n mlproject get jobsets
   kubectl -n mlproject get pods -o wide

Check the authoritative suspension fields:

.. code-block:: console

   kubectl -n mlproject get trainjob cpu-smoke-test \
     -o jsonpath='suspend={.spec.suspend}{"\n"}'

   kubectl -n mlproject get jobset cpu-smoke-test \
     -o jsonpath='suspend={.spec.suspend}{"\n"}'

The TrainJob printer's ``STATE`` column can briefly continue to display
``Suspended`` after ``spec.suspend`` becomes ``false``. The spec, JobSet state,
and presence of a Pod are the more useful indicators during this transition.

Inspect scheduling, events, and logs from the control node:

.. code-block:: console

   kubectl -n mlproject get pods -o wide
   kubectl -n mlproject describe trainjob cpu-smoke-test
   kubectl -n mlproject get events --sort-by='.lastTimestamp'
   kubectl -n mlproject logs POD_NAME --follow

Webhook certificate recovery
----------------------------

An ``x509: certificate signed by unknown authority`` error from a Kubeflow
Trainer admission webhook indicates that its serving certificate and webhook
CA bundle are inconsistent. First restart the Trainer controller and retry the
operation:

.. code-block:: console

   kubectl -n kubeflow-system rollout restart \
     deployment/kubeflow-trainer-controller-manager
   kubectl -n kubeflow-system rollout status \
     deployment/kubeflow-trainer-controller-manager --timeout=2m

If the error remains, rotate only the generated webhook certificate Secret:

.. code-block:: console

   kubectl -n kubeflow-system delete secret kubeflow-trainer-webhook-cert
   kubectl -n kubeflow-system create secret generic \
     kubeflow-trainer-webhook-cert

Wait until the Secret reports ``DATA 4`` before restarting the controller
again:

.. code-block:: console

   kubectl -n kubeflow-system get secret kubeflow-trainer-webhook-cert
   kubectl -n kubeflow-system rollout restart \
     deployment/kubeflow-trainer-controller-manager
   kubectl -n kubeflow-system rollout status \
     deployment/kubeflow-trainer-controller-manager --timeout=2m

The rotator repopulates this Secret and updates the webhook configurations.
The Secret contains generated webhook certificates, not user credentials.
Do not disable webhook validation to bypass certificate failures.

Offboarding
-----------

To remove Kubernetes access, delete the user's manifest from
``argocd/applications/mlprojects/users/`` and push the change. Argo CD pruning
removes the ServiceAccount and RoleBinding.

To remove login-node access, an administrator should lock or delete the Linux
account and remove its home directory only after preserving any required user
data. Also remove any remaining SSH public keys and revoke or delete the user's
Kubernetes credentials.
