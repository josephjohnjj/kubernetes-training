Indexd
======

Indexd maintains the persistent index of data object identifiers, locations,
checksums, sizes, and metadata used by GEN3 data-access workflows.

Configured values
-----------------

* ``enabled: true`` deploys Indexd with image tag ``2025.08``.
* PostgreSQL uses the fully qualified CloudNativePG endpoint, database
  ``indexd_gen3``, and role ``indexd_gen3``.
* ``defaultPrefix: PREFIX/`` is the chart-level default for newly created
  identifiers. Fence separately advertises ``gen31k/`` as its Indexd prefix;
  these values should be intentionally reconciled.
* uWSGI configuration is mounted at ``/etc/uwsgi/uwsgi.ini``.
* the 2025.08 settings module is mounted at ``/indexd/local_settings.py``.
* Gunicorn configuration is mounted at
  ``/indexd/deployment/wsgi/gunicorn.conf.py``.

The corrected settings mount is required because Indexd 2025.08 imports
``local_settings.py`` from its working directory.

Resources and verification
--------------------------

The chart renders ``indexd-deployment``, ``indexd-service``,
``indexd-dbcreate``, and ``indexd-userdb``::

   kubectl -n gen3 get deployment indexd-deployment
   kubectl -n gen3 get job indexd-dbcreate indexd-userdb
   kubectl -n gen3 logs deployment/indexd-deployment --all-containers --tail=100

