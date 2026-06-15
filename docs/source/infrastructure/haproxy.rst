HAProxy
=======

HAProxy is a high-performance TCP/HTTP load balancer and reverse proxy commonly used
to distribute traffic across multiple backend services. In Kubernetes environments,
it can be used to expose applications, route requests based on hostnames or paths,
and provide high availability for cluster services.

Configuration
-------------

The HAProxy configuration file used in this training environment is located at:

.. code-block:: text

   infrastructure/ansible/4_ha_proxy/haproxy.cfg

To modify the configuration, first create a backup of the existing configuration file
and then edit it:

.. code-block:: bash

   sudo cp /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.bak

Applying Changes
----------------

After updating the configuration, reload the HAProxy service to apply the changes
without interrupting existing connections:

.. code-block:: bash

   sudo systemctl reload haproxy

Verification
------------

Verify that HAProxy is listening on the expected port. The following example checks
for services listening on port ``5601``:

.. code-block:: bash

   sudo ss -tulnp | grep 5601

