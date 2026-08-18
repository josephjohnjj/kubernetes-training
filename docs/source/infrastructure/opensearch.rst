OpenSearch
==========

OpenSearch is an open-source search and analytics platform used for log
aggregation, observability, security analytics, and full-text search.
It provides distributed indexing and querying capabilities, while
OpenSearch Dashboards offers a web-based interface for visualizing and
exploring data.

Prerequisites
-------------

OpenSearch requires persistent storage. Before installation, ensure that
the desired StorageClass is configured as the cluster default.

Set the OpenSearch StorageClass as the default:

.. code-block:: bash

   kubectl patch storageclass opensearch-sc \
     -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

Installation
------------

Add the OpenSearch Helm repository and update the local cache:

.. code-block:: bash

   helm repo add opensearch https://opensearch-project.github.io/helm-charts/
   helm repo update

List available charts:

.. code-block:: bash

   helm search repo opensearch

Install the OpenSearch cluster using a custom values file:

.. code-block:: bash

   helm install opensearch opensearch/opensearch \
     -f manifests/opensearch/06-opensearch-values.yaml \
     -n opensearch

Install OpenSearch Dashboards:

.. code-block:: bash

   helm install opensearch-dashboard opensearch/opensearch-dashboards -n opensearch

Service Exposure
----------------

Expose OpenSearch Dashboards using a NodePort service:

.. code-block:: bash

   kubectl patch svc opensearch-dashboard-opensearch-dashboards -n opensearch -p '{"spec":{"type":"NodePort"}}'

Verification
------------

Verify that all pods are running:

.. code-block:: bash

   kubectl get pods -n opensearch

Verify services:

.. code-block:: bash

   kubectl get svc -n opensearch

Verify persistent volume claims:

.. code-block:: bash

   kubectl get pvc -n opensearch

Check the health of the OpenSearch cluster:

.. code-block:: bash

   kubectl get statefulsets -n opensearch

Monitoring and Troubleshooting
------------------------------

View OpenSearch pod logs:

.. code-block:: bash

   kubectl logs -n opensearch opensearch-cluster-master-0

View OpenSearch Dashboards logs:

.. code-block:: bash

   kubectl logs -n opensearch deployment/opensearch-dashboard-opensearch-dashboards

StorageClass Cleanup
--------------------

After installation, restore the original StorageClass configuration by
removing the default annotation from the OpenSearch StorageClass:

.. code-block:: bash

   kubectl patch storageclass opensearch-sc -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
