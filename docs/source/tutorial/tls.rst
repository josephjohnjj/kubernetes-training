```rst
Kubernetes TLS API Access Lab
==============================



The main idea is:

    ``kubectl`` is simply a client that communicates with the Kubernetes API server.

If you possess the correct TLS certificates and API endpoint information,
you can interact with Kubernetes directly using HTTPS requests.

This lab teaches how to:

- Extract TLS credentials from kubeconfig

- Decode certificates into PEM files

- Authenticate manually with ``curl``

- Query the Kubernetes API directly

- Create Kubernetes objects using REST API calls

Kubernetes is fundamentally an API-driven platform.

Architecture Overview
------------------

Normally the workflow looks like this:

.. code-block:: text

    kubectl
       |
       | HTTPS + TLS certificates
       v
    kube-apiserver
       |
       v
    Kubernetes Control Plane

In this lab, ``curl`` replaces ``kubectl``.



First, we will extract the TLS credentials from the kubeconfig file.
Then we will use those credentials to authenticate directly with the Kubernetes API server using ``curl``.


.. code-block:: bash

    less $HOME/.kube/config

The kubeconfig file contains:

- API server address

- Client certificate

- Client private key

- Certificate Authority (CA) certificate

These are the credentials automatically used by ``kubectl``.

Next, we will extract these values into environment variables.

.. code-block:: bash

    export client=$(grep client-cert $HOME/.kube/config | cut -d" " -f 6)

    echo $client



Purpose of the client certificate:

- Identifies the client to Kubernetes

- Functions similarly to authentication credentials

- Used during TLS authentication




.. code-block:: bash

    export key=$(grep client-key-data $HOME/.kube/config | cut -d" " -f 6)

    echo $key



Purpose of the private key:

- Proves ownership of the client certificate

- Used during TLS handshake

- Enables mutual TLS authentication

The certificate and key together form the client identity.




.. code-block:: bash

    export auth=$(grep certificate-authority-data $HOME/.kube/config | cut -d" " -f 6)

    echo $auth



Purpose of the CA certificate:

- Verifies the identity of the Kubernetes API server
- Prevents man-in-the-middle attacks
- Establishes trust with the server


Now we have the necessary credentials to authenticate with the Kubernetes API server directly using ``curl``.

The values stored in kubeconfig are Base64 encoded.

Convert them back into PEM files:

.. code-block:: bash

    echo $client | base64 -d - > ./client.pem
    echo $key | base64 -d - > ./client-key.pem
    echo $auth | base64 -d - > ./ca.pem




We have to provide these files to ``curl`` to authenticate with the Kubernetes API server.

Command:

.. code-block:: bash

    kubectl config view | grep server

    server: https://172.31.17.15:6443



This is the Kubernetes API endpoint.

Port ``6443`` is the default secure Kubernetes API port.



Now we can use ``curl`` to query the Kubernetes API server directly.

.. code-block:: bash

    curl --cert ./client.pem \
         --key ./client-key.pem \
         --cacert ./ca.pem \
         https://172.31.17.15:6443/api/v1/pods

This command bypasses ``kubectl`` completely and communicates directly
with the Kubernetes API server.


The internal workflow is similar to what happens when you run ``kubectl get pods``:

.. code-block:: text

    curl
      |
      | TLS Handshake
      |
      | "Here is my certificate"
      v
    kube-apiserver
      |
      | verifies certificate
      | checks RBAC permissions
      v
    returns pod list



The endpoint:

.. code-block:: text

    /api/v1/pods

contains:

=========== ======================
Part        Meaning
=========== ======================
/api        Core API path
v1          API version
pods        Resource type
=========== ======================

Examples of Kubernetes API Endpoints are:


=============================== ============================
Resource                        Endpoint
=============================== ============================
Pods                            /api/v1/pods
Services                        /api/v1/services
Nodes                           /api/v1/nodes
Deployments                     /apis/apps/v1/deployments
=============================== ============================


Now let's create a new Pod by sending a POST request to the Kubernetes API server.

.. code-block:: json

    {
      "kind": "Pod",
      "apiVersion": "v1",
      "metadata": {
        "name": "curlpod"
      },
      "spec": {
        "containers": [{
          "name": "nginx",
          "image": "nginx"
        }]
      }
    }

This is the raw Kubernetes object definition.

Although users commonly write YAML, Kubernetes internally converts YAML
to JSON before sending requests to the API server.


.. code-block:: bash

    curl --cert ./client.pem \
         --key ./client-key.pem \
         --cacert ./ca.pem \
         https://k8scp:6443/api/v1/namespaces/default/pods \
         -XPOST \
         -H 'Content-Type: application/json' \
         -d @curlpod.json

This command creates a Pod directly through the Kubernetes REST API.


.. code-block:: bash

    kubectl get pods


    NAME                   READY   STATUS    RESTARTS   AGE
    curlpod                1/1     Running   0          33s
    hog-54849dd678-8q85k   1/1     Running   0          7d2h



REST Concepts
--------------

================= ====================
REST Operation    HTTP Verb
================= ====================
Read              GET
Create            POST
Update            PUT/PATCH
Delete            DELETE
================= ====================

This lab uses:

.. code-block:: text

    POST

because a new resource is being created.



The endpoint:

.. code-block:: text

    /api/v1/namespaces/default/pods

includes the namespace because Pods are namespace-scoped resources.

Kubernetes therefore requires:

1. Resource type
2. Namespace

before creating the object.

What Happens After POST - Once the Pod specification is submitted:

.. code-block:: text

    Desired State:
    "Run an nginx pod"

the Kubernetes control plane begins reconciliation.

The process:

1. Scheduler selects a node
2. Kubelet receives instructions
3. Container runtime launches nginx
4. Pod transitions to Running state

This demonstrates Kubernetes' declarative model.

Users specify desired state, and Kubernetes works continuously to
match actual state to the requested state.

