Kubernetes APIs
=================

Kubernetes is built on a powerful, REST-based API. Every operation within the cluster, whether it comes from internal 
components or external users, is driven through this API. The kube-apiserver acts as the central communication hub. 
It manages requests from both within the cluster and from external clients.

.. note::

    REST stands for Representational State Transfer. It is an architectural style for designing networked applications.
    RESTful APIs use HTTP requests to perform operations on resources. The common HTTP methods used in RESTful APIs include:

    GET - retrieve information about a resource or a list of resources.
    POST - create a new resource.
    DELETE - remove a resource.



The `kubectl auth can-i subcommand` lets you test specific operations. Use the command to query whether a user can perform specific actions on 
resources. 

.. code-block:: bash

    kubectl auth can-i create deployments


Annotations are key-value pairs that can be attached to Kubernetes objects. They are used to store arbitrary metadata about the object.

.. code-block:: bash

    kubectl annotate pods --all description='Test Pods' -n default

    pod/hog-54849dd678-8q85k annotated


.. code-block:: bash

    kubectl get pod hog-54849dd678-8q85k -o yaml

To update an annotation, you can use the `--overwrite` flag:

.. code-block:: yaml

    kubectl annotate pod hog-54849dd678-8q85k   owner="platform-team"   --overwrite

    kubectl describe pod hog-54849dd678-8q85k 


To remove an annotation, you can use the `kubectl annotate` command with a `-` at the end of the annotation key:

.. code-block:: bash

    kubectl annotate pod hog-54849dd678-8q85k   description-


To locate the basic server connection details, including cluster addresses and certificate information, you can run the command below:

.. code-block:: bash

    kubectl config view






