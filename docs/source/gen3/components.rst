GEN3 Application Components
===========================

These pages describe every application component rendered by the effective
GEN3 2025.08 Argo CD values. Values are merged in the order recorded in
``argocd/applications/gen3/02-gen3.yaml``.

.. toctree::
   :maxdepth: 1
   :titlesonly:

   components/arborist
   components/audit
   components/fence
   components/indexd
   components/sheepdog
   components/peregrine
   components/metadata
   components/manifestservice
   components/etl
   components/guppy
   components/portal
   components/revproxy
   components/hatchery
   components/wts

The order follows the main data and request paths rather than alphabetical
order. PostgreSQL, Elasticsearch, Ceph, Keycloak, and ingress-nginx are platform
dependencies and are documented in their own GEN3 pages.
