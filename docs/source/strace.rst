Strace
==================

In this section, we will explore how to debug issues related to the Kubernetes API server. 

.. code-block:: bash

    sudo apt-get install -y strace

.. code-block:: bash

    kubectl get endpoints 
   
    NAME         ENDPOINTS           AGE
    kubernetes   172.31.17.15:6443   84d


The above command helps you see everything kubectl is asking the Linux kernel to do while it executes.


Now we will use ``strace`` to trace the system calls made by the Kubernetes API server when we 
run a command like ``kubectl get pods``.

.. code-block:: bash

    strace kubectl get endpoints


There will be a lot of output, but this will be written to `~/.kube/cache/discovery/` directory.
Inside it, Kubernetes stores cached API discovery info:

.. code-block:: bash

    cd ~/.kube/cache/discovery/
    ls

    172.31.17.15_6443


.. code-block:: bash

    cd 172.31.17.15_6443
    ls

    find .

This will show you all the files that were created by `strace` when you ran the 
`kubectl get endpoints` command. We are interested in the `v1` file which contains the API response 
from the Kubernetes API server.

.. code-block:: bash

    python3 -m json.tool ./admissionregistration.k8s.io/v1/serverresources.json 

    {
        "kind": "APIResourceList",
        "apiVersion": "v1",
        "groupVersion": "admissionregistration.k8s.io/v1",
        "resources": [
            {
                "name": "mutatingwebhookconfigurations",
                "singularName": "mutatingwebhookconfiguration",
                "namespaced": false,
                "kind": "MutatingWebhookConfiguration",
                "verbs": [
                    "create",
                    "delete",
                    "deletecollection",
                    "get",
                    "list",
                    "patch",
                    "update",
                    "watch"
                ],
                "categories": [
                    "api-extensions"
                ]
            
The `json.tool` command formats the JSON output in a more readable way. 
You can see that the API response contains a list of resources that are available in the Kubernetes 
API server.