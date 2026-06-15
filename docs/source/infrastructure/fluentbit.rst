Fluent Bit
==========

Fluent Bit is a lightweight and high-performance log processor and forwarder.
In Kubernetes environments, it is commonly deployed as a DaemonSet to collect
container logs from every node and forward them to centralized logging platforms
such as OpenSearch, Elasticsearch, Splunk, Loki, or cloud logging services.

Prerequisites
-------------

Ensure that a destination logging platform is available before deploying
Fluent Bit. Typical destinations include OpenSearch clusters, Elasticsearch,
or other log aggregation systems.

Installation
------------

Add the Fluent Helm repository and update the local cache:

.. code-block:: bash

   helm repo add fluent https://fluent.github.io/helm-charts
   helm repo update

Create a dedicated namespace:

.. code-block:: bash

   kubectl create ns fluentbit

Install Fluent Bit using the default chart configuration:

.. code-block:: bash

   helm install fluent-bit fluent/fluent-bit -n fluentbit

Configuration
-------------

Apply custom configuration values by upgrading the release with a
``infrastructure/ansible/12_fluentbit/values.yaml`` file:

.. code-block:: bash

   helm upgrade fluent-bit fluent/fluent-bit -f values.yaml -n fluentbit

The ``values.yaml`` file can be used to configure:

* Log inputs and parsers
* Output destinations
* Filters and enrichments
* Resource requests and limits
* Buffer and storage settings

Verification
------------

Verify that the Fluent Bit pods are running:

.. code-block:: bash

   kubectl get pods -n fluentbit

Verify the DaemonSet status:

.. code-block:: bash

   kubectl get daemonset -n fluentbit

Confirm that Fluent Bit is deployed on all worker nodes:

.. code-block:: bash

   kubectl get daemonset fluent-bit -n fluentbit

Monitoring and Troubleshooting
------------------------------

View Fluent Bit logs:

.. code-block:: bash

   kubectl logs -n fluentbit daemonset/fluent-bit

View pod details:

.. code-block:: bash

   kubectl describe pods -n fluentbit

Check the Helm release status:

.. code-block:: bash

   helm status fluent-bit -n fluentbit


