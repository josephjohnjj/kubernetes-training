CloudNativePG (CNPG)
====================

CloudNativePG (CNPG) is a Kubernetes-native PostgreSQL operator that manages
the full lifecycle of PostgreSQL clusters. It provides automation for provisioning,
scaling, backups, failover, and high availability of PostgreSQL databases in
Kubernetes environments.

CNPG is commonly used for production-grade database workloads where reliability,
automation, and declarative database management are required.

CNPG provides the following capabilities:

* Automated PostgreSQL cluster provisioning
* High availability with automatic failover
* Streaming replication between primary and replicas
* Automated backups and recovery
* Rolling updates for database version upgrades
* Kubernetes-native declarative configuration

Storage Setup
-------------

Before deploying CNPG, configure storage resources required for PostgreSQL
clusters.

Create required storage and pool configurations:

.. code-block:: bash

   kubectl create -f storage/rook-ceph/storage/cephpool/01-cnpg-pool.yaml
   kubectl create -f storage/rook-ceph/storage/storageclasses/01-cnpg-sc.yaml

Configuration file locations:

.. code-block:: text

   storage/rook-ceph/storage/cephpool/01-cnpg-pool.yaml
   storage/rook-ceph/storage/storageclasses/01-cnpg-sc.yaml

Set the CNPG StorageClass as the default (if required for cluster provisioning):

.. code-block:: bash

   kubectl patch storageclass cnpg-sc -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

Helm Installation (Operator)
----------------------------

Add the CloudNativePG Helm repository:

.. code-block:: bash

   helm repo add cnpg https://cloudnative-pg.github.io/charts

Install the CNPG operator into the cluster:

.. code-block:: bash

   helm upgrade --install cnpg --namespace cnpg-system --create-namespace cnpg/cloudnative-pg

This installs the **CNPG operator**, which is responsible for managing PostgreSQL
clusters in Kubernetes.





Verification
------------

Check CNPG operator pods:

.. code-block:: bash

   kubectl get pods -n cnpg-system

Check database clusters:

.. code-block:: bash

   kubectl get clusters -A

Check PostgreSQL pods:

.. code-block:: bash

   kubectl get pods -n cnpg-database

Check PVCs:

.. code-block:: bash

   kubectl get pvc -n cnpg-database



Monitoring and Troubleshooting
------------------------------

View operator logs:

.. code-block:: bash

   kubectl logs -n cnpg-system deployment/cnpg-controller-manager

Database Creation for Keycloak
------------------------------

After the CloudNativePG PostgreSQL cluster has been deployed, create a
dedicated database and user for Keycloak.

Create Application User
~~~~~~~~~~~~~~~~~~~~~~~~~

Connect to PostgreSQL using the cluster superuser and create a dedicated
user for Keycloak.

.. code-block:: sql

   CREATE USER keycloak WITH PASSWORD 'keycloak-pwd';

This creates a PostgreSQL role that Keycloak will use to connect to the
database.


Create a database owned by the Keycloak user.

.. code-block:: sql

   CREATE DATABASE keycloak OWNER keycloak;



Grant full privileges on the database to the Keycloak user.

.. code-block:: sql

   GRANT ALL PRIVILEGES ON DATABASE keycloak TO keycloak;



Switch to the newly created database.

.. code-block:: sql

   \c keycloak



Transfer ownership of the default ``public`` schema to the Keycloak user.

.. code-block:: sql

   ALTER SCHEMA public OWNER TO keycloak;



Grant full access to the ``public`` schema.

.. code-block:: sql

   GRANT ALL ON SCHEMA public TO keycloak;



Ensure all future tables created in the schema automatically grant
permissions to the Keycloak user.

.. code-block:: sql

   ALTER DEFAULT PRIVILEGES IN SCHEMA public
   GRANT ALL ON TABLES TO keycloak;



Ensure all future sequences created in the schema automatically grant
permissions to the Keycloak user.

.. code-block:: sql

   ALTER DEFAULT PRIVILEGES IN SCHEMA public
   GRANT ALL ON SEQUENCES TO keycloak;



Confirm that the ``public`` schema is owned by the Keycloak user.

.. code-block:: sql

   \dn+

Expected output:

.. code-block:: text

   Name   | Owner
   -------+---------
   public | keycloak

The database is now ready for use by Keycloak.
