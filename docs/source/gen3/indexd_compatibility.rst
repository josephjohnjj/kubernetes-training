Indexd 2025.08 Compatibility
===========================

This page records the changes required to run ``quay.io/cdis/indexd:2025.08``
with the vendored GEN3 Helm chart and the external CloudNativePG database. The
deployment is reconciled by Argo CD from ``charts/gen3-2025.08``.

Final architecture
------------------

Indexd uses the following configuration flow::

   indexd-dbcreds Secret
           |
           v
   PGHOST, PGUSER, PGPASSWORD, PGDB
           |
           v
   /indexd/local_settings.py
           |
           v
   chart-managed WSGI bootstrap
           |
           v
   get_app(settings)
           |
           v
   indexd_gen3 on CloudNativePG

The external PostgreSQL endpoint is
``gen3-db-cluster-rw.gen3-db.svc.cluster.local:5432``. Indexd does not use a
PostgreSQL server in its own pod.

Observed failures
-----------------

The original deployment failed in several distinct stages.

Image and chart mismatch
~~~~~~~~~~~~~~~~~~~~~~~~

A mutable ``master`` image did not match the filesystem and startup conventions
expected by the chart. Errors included missing WSGI modules. The deployment was
stabilized by vendoring the GEN3 chart and pinning Indexd and the other core
components to the ``2025.08`` release.

Incorrect database credentials
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Two Argo CD applications initially managed service database Secrets. This
caused ``indexd-dbcreds`` to contain the shared ``gen3db`` identity instead of
the service database identity. Ownership was consolidated so that the GEN3
chart exclusively creates service-specific Secrets. Indexd now uses the
``indexd_gen3`` role and database.

The database creation workflow also requires the ``dbcreated`` key. A missing
key prevents Kubernetes from creating the Indexd container because ``DBREADY``
references it as a required Secret key. With database creation enabled, the
``indexd-dbcreate`` Job creates the database and role and records
``dbcreated=true``.

Fallback to localhost
~~~~~~~~~~~~~~~~~~~~~

The pinned image started Gunicorn with
``deployment.wsgi.wsgi:application``. Its bundled WSGI module called
``get_app()`` without passing the chart settings. Indexd consequently loaded
``indexd.default_settings`` and attempted PostgreSQL on ``localhost:5432`` even
though the pod had correct ``PG*`` environment variables.

The chart now mounts a WSGI bootstrap over
``/indexd/deployment/wsgi/wsgi.py``. It adds the application directory to the
Python import path, imports the mounted settings, and passes them explicitly::

   import sys

   sys.path.insert(0, "/indexd")

   from local_settings import settings
   from indexd import get_app

   application = get_app(settings)

This compatibility layer is defined in
``charts/gen3-2025.08/charts/indexd/templates/wsgi-bootstrap.yaml`` and mounted
by the Indexd Deployment template.

Missing settings file
~~~~~~~~~~~~~~~~~~~~~

The WSGI bootstrap initially failed with::

   ModuleNotFoundError: No module named 'local_settings'

The live ``indexd-settings`` Secret contained ``data: {}``. The chart used a
file glob to create the Secret, while the repository-wide ``.gitignore`` rule
excluded ``local_settings.py``. Local Helm rendering appeared to work because
the ignored file existed in the working tree, but Argo CD could not see it in
its Git checkout.

The non-secret, environment-driven template is now force-tracked at
``charts/gen3-2025.08/charts/indexd/indexd-settings/local_settings.py``. The
Secret template uses an explicit file lookup::

   data:
     local_settings.py: {{ .Files.Get "indexd-settings/local_settings.py" | b64enc | quote }}

The resulting Secret is mounted at ``/indexd/local_settings.py``. Actual
passwords remain in ``indexd-dbcreds`` and enter the application through
environment variables; they are not stored in this Python template.

Helm changes
------------

The compatibility work affects these files:

* ``charts/gen3-2025.08/values/gen3-values.yaml`` pins the Indexd image and
  configures the settings mount.
* ``charts/gen3-2025.08/charts/indexd/templates/deployment.yaml`` mounts the
  WSGI bootstrap.
* ``charts/gen3-2025.08/charts/indexd/templates/wsgi-bootstrap.yaml`` loads and
  passes the chart settings explicitly.
* ``charts/gen3-2025.08/charts/indexd/templates/indexd-secret.yaml`` renders
  ``local_settings.py`` explicitly.
* ``charts/gen3-2025.08/charts/indexd/templates/pre-install.yaml`` uses the same
  settings location for the Indexd initialization workflow.
* ``charts/gen3-2025.08/validate.sh`` checks the image pins, mounts, bootstrap,
  and non-empty settings Secret.

Validation
----------

Run the repository validation before committing chart changes::

   ./charts/gen3-2025.08/validate.sh

The validation performs Helm linting and renders the complete Argo CD values
set. It fails if the WSGI bootstrap is absent or if
``indexd-settings.data["local_settings.py"]`` is missing or empty.

After an Argo CD sync, confirm that the settings file exists without printing
its encoded contents::

   kubectl -n gen3 get secret indexd-settings -o json |
   jq -r '
     if (.data["local_settings.py"] | length) > 0
     then "local_settings.py: present"
     else "local_settings.py: MISSING"
     end
   '

Confirm the active pod mounts both files::

   POD=$(kubectl -n gen3 get pods -l app=indexd \
     --sort-by=.metadata.creationTimestamp \
     -o jsonpath='{.items[-1:].metadata.name}')

   kubectl -n gen3 get pod "$POD" \
     -o jsonpath='{range .spec.containers[0].volumeMounts[*]}{.mountPath}{" <- "}{.name}{"/"}{.subPath}{"\n"}{end}'

The output must include::

   /indexd/local_settings.py <- config-volume/local_settings.py
   /indexd/deployment/wsgi/wsgi.py <- indexd-wsgi-bootstrap/wsgi.py

Finally, verify application health::

   kubectl -n gen3 rollout status deployment/indexd-deployment --timeout=5m
   kubectl -n gen3 get deployment indexd-deployment
   kubectl -n gen3 logs deployment/indexd-deployment -c indexd --tail=100

A compatible deployment reports ``1/1`` ready. Its logs must not contain
``ModuleNotFoundError`` or PostgreSQL connection attempts to ``localhost``.

Operational notes
-----------------

* Do not define ``indexd-dbcreds`` under ``postgres/secrets``. The GEN3 Helm
  chart owns that service Secret.
* Do not use mutable Indexd image tags such as ``master`` or ``latest``.
* A Secret or ConfigMap change mounted with ``subPath`` requires a new pod to
  consume the new content. Allow the Deployment rollout to create one, or use
  ``kubectl rollout restart`` after Argo CD has applied the desired resources.
* Old failed pods and Jobs are historical objects. Assess the newest ReplicaSet
  and the current Deployment readiness when determining health.
