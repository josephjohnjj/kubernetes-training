Keycloak and PostgreSQL Database Setup
======================================

Short Answer
------------

You should create the PostgreSQL database yourself.
Keycloak will NOT reliably create it for you.

---

How It Works
------------

Keycloak connects to PostgreSQL in two main steps:

1. Connect to an existing database
2. Initialize schema inside that database

You configure:

- Host
- Username
- Password
- Database name

---

What Keycloak Creates vs What You Create
----------------------------------------

+---------------------------+------------------------------+
| Component                 | Who creates it              |
+===========================+==============================+
| PostgreSQL server        | You / Helm / Operator       |
+---------------------------+------------------------------+
| Database (e.g. keycloak) | ❌ You should create it     |
+---------------------------+------------------------------+
| Tables / schema          | ✅ Keycloak creates         |
+---------------------------+------------------------------+

---

Why You Should Create the Database
-----------------------------------

Keycloak expects the database to already exist because:

- PostgreSQL users may not have permission to create databases
- Kubernetes setups prefer explicit provisioning
- Helm/operator deployments assume external DB setup
- Avoids startup failures and ambiguity

---

Best Practice (Kubernetes Environment)
---------------------------------------

Step 1: Create database and user in PostgreSQL
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block:: sql

   CREATE DATABASE keycloak;
   CREATE USER keycloak WITH ENCRYPTED PASSWORD 'strongpassword';
   GRANT ALL PRIVILEGES ON DATABASE keycloak TO keycloak;

---

Step 2: Configure Keycloak Helm values
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block:: yaml

   externalDatabase:
     host: postgresql.keycloak.svc.cluster.local
     database: keycloak
     user: keycloak
     password: strongpassword

---

Step 3: Deploy Keycloak
~~~~~~~~~~~~~~~~~~~~~~~~

.. code-block:: bash

   helm upgrade keycloak bitnami/keycloak -n keycloak -f values.yaml

---

Important Notes
----------------

- Keycloak will NOT create the database in external PostgreSQL setups
- Keycloak WILL create internal tables and schema inside the database
- Database creation is an administrative responsibility

---

Exception Cases
---------------

Some Bitnami PostgreSQL Helm charts may auto-create a database when:

.. code-block:: yaml

   auth:
     database: keycloak

However:

- This only applies to internal PostgreSQL deployments
- It is NOT reliable for external databases
- Not recommended for production systems

---

Simple Rule
-----------

- PostgreSQL admin → creates database + user
- Keycloak → creates schema + tables

---

Recommended Architecture (Your Setup)
--------------------------------------

- Ceph RBD → persistent storage
- PostgreSQL → pre-provisioned database
- Keycloak → stateless application

Flow:

::

   Keycloak → PostgreSQL (pre-created database)
