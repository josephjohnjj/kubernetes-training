Audit
=====

Audit records security and activity events produced by GEN3 services.

Configured values
-----------------

* ``enabled: true`` deploys Audit.
* ``image.tag: 2025.08`` and ``pullPolicy: IfNotPresent`` pin runtime behavior.
* ``postgres.username: audit_gen3`` selects the Audit database role.
* ``serviceAccount.create: true`` creates ``audit-service-sa``.
* The service-account AWS role annotation is empty because this deployment is
  not using an EKS IAM role for Audit.

Audit inherits the shared PostgreSQL host and uses database ``audit_gen3``.
Its password must be supplied through a Secret instead of plain Helm values.

Resources and dependencies
--------------------------

The chart renders ``audit-deployment``, ``audit-service``, and
``audit-dbcreate``. It depends on PostgreSQL and receives events from other
GEN3 applications.

Verify::

   kubectl -n gen3 get deployment audit-deployment
   kubectl -n gen3 get serviceaccount audit-service-sa
   kubectl -n gen3 get job audit-dbcreate
   kubectl -n gen3 logs deployment/audit-deployment --tail=100

