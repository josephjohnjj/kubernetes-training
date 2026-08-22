Fence
=====

Fence provides authentication, token handling, user synchronization, and
access integration for GEN3. This deployment authenticates through Keycloak.

Configured values
-----------------

* ``enabled: true`` and image tag ``2025.08`` deploy the selected release.
* PostgreSQL endpoint ``gen3-db-cluster-rw.gen3-db:5432`` uses database and
  role ``fence_gen3``.
* Indexd URL ``http://indexd-service`` uses no basic authentication and default
  prefix ``gen31k/``.
* ``usersync.usersync: true`` schedules UserSync every 30 minutes.
* The active POC sets ``userYamlS3Path: "none"`` and uses the chart's embedded
  ``USER_YAML``.
* The commented S3 option reads ``s3://users-bucket/users.yaml`` through Ceph
  RGW and uses credentials from Secret ``users-bucket`` when enabled.
* dbGaP synchronization and Slack notifications are disabled.
* Service account ``fence-service-sa`` is created without an EKS role.

OIDC values
-----------

The provider is named ``generic_oidc_idp``. It uses Keycloak realm ``genome``,
client ID ``gen3-fence``, claim ``email``, and scope ``openid email``. Keycloak
is the default login option. Fence performs Keycloak discovery over HTTPS, and
the public callback uses HTTPS with the external Revproxy path
``/user/login/generic_oidc_idp/login``. See :doc:`../keycloak` for the matching
Keycloak client configuration.

.. warning::

   Database, S3, and OIDC client secrets are also present as literal values in
   current overlays. Rotate them and source them only from Secrets.

Resources and verification
--------------------------

Fence renders the main and presigned-URL Deployments, ``fence-dbcreate``, the
``usersync`` CronJob, and an expired-client cleanup CronJob::

   kubectl -n gen3 get deployment fence-deployment presigned-url-fence-deployment
   kubectl -n gen3 get job fence-dbcreate
   kubectl -n gen3 get cronjob usersync fence-delete-expired-clients
   kubectl -n gen3 logs deployment/fence-deployment --tail=100
