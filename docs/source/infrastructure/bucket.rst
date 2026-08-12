GEN3 Fence UserSync - Ceph S3 Setup
=======================================

This document records the Ceph S3 setup used for the GEN3 Fence UserSync
``users.yaml`` process.

1. Create the data store
------------------------

A Rook-Ceph ``CephObjectStore`` was created with:

* Name: ``gen3-store``
* Namespace: ``rook-ceph``

Verify it with::

    kubectl get cephobjectstore -A

The object store was ``Ready`` and provided the RGW endpoint::

    http://rook-ceph-rgw-gen3-store.rook-ceph.svc:80

2. Create the bucket
--------------------

The bucket was created using a Rook-Ceph ``ObjectBucketClaim`` (OBC).

Manifest::

    apiVersion: objectbucket.io/v1alpha1
    kind: ObjectBucketClaim
    metadata:
      name: gen3-user-yaml
      namespace: gen3-1000g
    spec:
      generateBucketName: gen3-user-yaml-
      storageClassName: gen3-bucket

Verify it with::

    kubectl get objectbucketclaim gen3-user-yaml \
      -n gen3-1000g -o yaml

The OBC reached::

    status:
      phase: Bound

The actual bucket created by Rook-Ceph was::

    gen3-user-yaml--7d98910d-a1be-40f8-bf1c-414b89c41aaa

The OBC object bucket name was::

    obc-gen3-1000g-gen3-user-yaml

The bucket connection information was available in the ConfigMap
``gen3-user-yaml`` in namespace ``gen3-1000g``::

    kubectl get configmap gen3-user-yaml \
      -n gen3-1000g -o yaml

Relevant values::

    BUCKET_HOST: rook-ceph-rgw-gen3-store.rook-ceph.svc
    BUCKET_NAME: gen3-user-yaml--7d98910d-a1be-40f8-bf1c-414b89c41aaa
    BUCKET_PORT: "80"

3. Create the S3 user
---------------------

A Rook-Ceph ``CephObjectStoreUser`` was created for the GEN3 Fence UserSync
process.

Manifest::

    apiVersion: ceph.rook.io/v1
    kind: CephObjectStoreUser
    metadata:
      name: gen3-usersync
      namespace: rook-ceph
    spec:
      store: gen3-store
      displayName: "Gen3 Fence user.yaml sync"

Verify it with::

    kubectl get cephobjectstoreuser gen3-usersync \
      -n rook-ceph

The user reached::

    PHASE
    Ready

The OBC-created Secret used for the bucket credentials was::

    gen3-user-yaml

in namespace ``gen3-1000g``.

4. Find the ACCESS_KEY
----------------------

The Secret was verified with::

    kubectl get secret -n gen3-1000g | grep gen3-user-yaml

The access key is stored in ``AWS_ACCESS_KEY_ID``.

Extract it with::

    kubectl get secret gen3-user-yaml \
      -n gen3-1000g \
      -o jsonpath='{.data.AWS_ACCESS_KEY_ID}' | base64 -d

The decoded value is the S3 access key used by the AWS CLI and Fence.

Do not commit the decoded key to Git.

5. Find the ACCESS_SECRET
-------------------------

The secret access key is stored in ``AWS_SECRET_ACCESS_KEY``.

Extract it with::

    kubectl get secret gen3-user-yaml \
      -n gen3-1000g \
      -o jsonpath='{.data.AWS_SECRET_ACCESS_KEY}' | base64 -d

The decoded value is the S3 secret key used by the AWS CLI and Fence.

Do not commit the decoded secret to Git.

6. Create users.yaml
--------------------

A ``users.yaml`` file was created on ``control1`` for testing::

    nano users.yaml

The file was populated with the GEN3 user information required by the
installed Fence UserSync configuration.

The file is stored in the Ceph S3 bucket at::

    s3://gen3-user-yaml--7d98910d-a1be-40f8-bf1c-414b89c41aaa/users.yaml

The exact contents of ``users.yaml`` must match the UserSync format expected
by the installed GEN3/Fence version.

7. Upload users.yaml
--------------------

The Ceph RGW service is a Kubernetes ``ClusterIP`` service, so it is not
directly reachable from ``control1`` using the Kubernetes service DNS name.

A temporary port-forward was used::

    kubectl port-forward -n rook-ceph \
      svc/rook-ceph-rgw-gen3-store 8080:80

This made the RGW endpoint available locally at::

    http://127.0.0.1:8080

The S3 credentials from the ``gen3-user-yaml`` Secret were exported::

    export AWS_ACCESS_KEY_ID=$(kubectl get secret gen3-user-yaml \
      -n gen3-1000g \
      -o jsonpath='{.data.AWS_ACCESS_KEY_ID}' | base64 -d)

    export AWS_SECRET_ACCESS_KEY=$(kubectl get secret gen3-user-yaml \
      -n gen3-1000g \
      -o jsonpath='{.data.AWS_SECRET_ACCESS_KEY}' | base64 -d)

The file was uploaded with::

    aws --endpoint-url http://127.0.0.1:8080 \
      s3 cp users.yaml \
      s3://gen3-user-yaml--7d98910d-a1be-40f8-bf1c-414b89c41aaa/users.yaml

The final S3 object location is::

    s3://gen3-user-yaml--7d98910d-a1be-40f8-bf1c-414b89c41aaa/users.yaml

8. Resulting setup
------------------

The resulting setup is::

    Rook-Ceph
      |
      +-- CephObjectStore: gen3-store
      |       |
      |       +-- RGW
      |             |
      |             +-- Bucket:
      |                 gen3-user-yaml--7d98910d-a1be-40f8-bf1c-414b89c41aaa
      |
      +-- CephObjectStoreUser: gen3-usersync
      |
      +-- Secret: gen3-user-yaml
              |
              +-- AWS_ACCESS_KEY_ID
              +-- AWS_SECRET_ACCESS_KEY

    Bucket
      |
      +-- users.yaml