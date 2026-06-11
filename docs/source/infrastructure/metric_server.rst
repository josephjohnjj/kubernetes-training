Metrics Server Installation via Helm
====================================


First, add the official Helm repository for Metrics Server:

.. code-block:: bash

    helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
    helm repo update


Basic Installation
------------------

Install the Metrics Server using the default configuration:

.. code-block:: bash

    helm upgrade --install metrics-server metrics-server/metrics-server


Installation in kube-system Namespace with Custom Settings
----------------------------------------------------------

For production-like environments, install the Metrics Server in the ``kube-system`` namespace
and configure secure port and kubelet TLS settings:

.. code-block:: bash

    helm upgrade --install metrics-server metrics-server/metrics-server \
        --namespace kube-system \
        --set args="{--secure-port=10251,--kubelet-insecure-tls}" \
        --set containerPort=10251


Verification
------------

Check that the Metrics Server pods are running:

.. code-block:: bash

    kubectl get pods -n kube-system


View resource usage for pods:

.. code-block:: bash

    kubectl top pods -n kube-system

