Manifest Service
================

Manifest Service creates and retrieves collections of data object references
used by download and analysis workflows.

Configured values
-----------------

* ``enabled: true`` deploys the service.
* ``image.tag: 2025.08`` pins it to the selected GEN3 release.
* ``image.pullPolicy: IfNotPresent`` uses cached images when available.

No component-specific database override is set in the environment file. The
service therefore uses its chart defaults and global GEN3 configuration. Its
configuration Secret is rendered as ``manifestservice-g3auto``.

Resources and dependencies
--------------------------

The chart renders ``manifestservice-deployment``,
``manifestservice-service``, and ``manifestservice-sa``. It integrates with
Fence and Indexd for authorized manifest operations.

Verify::

   kubectl -n gen3 get deployment manifestservice-deployment
   kubectl -n gen3 get service manifestservice-service
   kubectl -n gen3 logs deployment/manifestservice-deployment --tail=100

