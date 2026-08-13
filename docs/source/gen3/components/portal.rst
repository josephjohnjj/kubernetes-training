Portal
======

Portal is the user-facing GEN3 web application. It is served through Revproxy
and queries Guppy for explorer data.

Runtime values
--------------

* ``enabled: true`` deploys Portal with image tag ``2025.08``.
* Annotation ``secret.reloader.stakater.com/reload: portal-config`` requests a
  rollout when the generated configuration Secret changes, assuming the
  Reloader controller is installed.
* Resource requests are ``500m`` CPU and ``1Gi`` memory.
* Resource limits are 2 CPUs and ``4Gi`` memory.

GitOps UI configuration
-----------------------

The CSS overlay loads the Montserrat font and applies a blue/red custom theme,
navigation and footer colors, selected explorer-tab styling, and a wider chart
layout with a four-column legend.

The JSON overlay sets:

* Application name and title to ``Gen3 Proof of Concept``.
* Navigation entries for Dictionary, Exploration, and Profile.
* Public explorer and explorer features to enabled.
* Analysis and discovery features to disabled.
* One ``Cases`` explorer tab backed by Guppy type ``case``.
* Case, sample, and aliquot counts.
* Charts and filters for project, disease, site, gender, race, and ethnicity.
* A results table containing the corresponding case fields.

These fields must remain aligned with ``00-etl-mapping.yaml`` and Guppy. A
Portal field not produced by Tube will be empty or cause query errors.

Verify::

   kubectl -n gen3 get deployment portal-deployment
   kubectl -n gen3 get secret portal-config
   kubectl -n gen3 logs deployment/portal-deployment --tail=100

