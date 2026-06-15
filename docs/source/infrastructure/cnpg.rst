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

   kubectl create -f cnpg-pool.yaml
   kubectl create -f cnpg-sc.yaml

Configuration file locations:

.. code-block:: text

   infrastructure/ansible/15_cnpg_system/cnpg-pool.yaml
   infrastructure/ansible/15_cnpg_system/cnpg-sc.yaml

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

