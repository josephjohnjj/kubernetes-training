GEN3 Version Matrix
===================

Record versions before every installation and upgrade. Do not infer the
deployed version from a directory name alone.

Repository-pinned versions
--------------------------

.. list-table::
   :header-rows: 1
   :widths: 35 25 40

   * - Component
     - Version
     - Source of truth
   * - GEN3 Helm chart
     - ``0.2.21``
     - ``charts/gen3-2025.08/Chart.yaml``
   * - GEN3 application images
     - ``2025.08``
     - ``charts/gen3-2025.08/values/gen3-values.yaml``
   * - PostgreSQL
     - ``13``
     - ``postgres/db/01-gen3-db.yaml``
   * - Elasticsearch
     - ``9.5.0``
     - ``charts/eck-stack/elasticsearch-values.yaml``
   * - Ceph
     - ``v20.2.1``
     - ``storage/rook-ceph/cluster/01-rook-ceph-cluster.yaml``
   * - ingress-nginx chart
     - ``4.15.1``
     - ``charts/ingress-nginx/Chart.yaml``
   * - ingress-nginx controller
     - ``1.15.1``
     - ``charts/ingress-nginx/Chart.yaml``
   * - Keycloak image
     - ``26.3.3-debian-12-r0``
     - ``manifests/keycloak/03-keycloak-values.yaml``
   * - Keycloak Helm chart
     - ``25.2.0``
     - Tested Helm installation; record with ``helm list -n keycloak``

The vendored GEN3 chart has ``appVersion: master``. That field is not used as
the runtime release identifier here; enabled service images are explicitly
pinned to ``2025.08`` in the environment values.

Versions to record at deployment time
-------------------------------------

Some operator charts are vendored but may change in later commits. Capture the
Git commit and all rendered workload images for an auditable deployment::

   git rev-parse HEAD
   kubectl version
   helm version
   kubectl -n argocd get application -o wide
   kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{range .spec.containers[*]}{.image}{" "}{end}{"\n"}{end}'

Save the output with the change record. Container tags are useful labels, but
immutable image digests provide stronger reproducibility::

   kubectl -n gen3 get pods \
     -o jsonpath='{range .items[*].status.containerStatuses[*]}{.name}{"\t"}{.imageID}{"\n"}{end}'

Upgrade policy
--------------

Upgrade one layer at a time and keep database and object-store backups outside
the change boundary. Update the matrix, render the Helm chart, review the diff,
test in a non-production environment, and then promote the same Git commit and
image digests.

Never combine credential rotation, database migration, storage migration, and
a GEN3 release change into one untested rollout.
