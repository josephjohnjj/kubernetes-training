Helm
==========

Helm is a package manager for Kubernetes that simplifies deploying and managing applications using reusable packages called *charts*. 
Instead of writing and maintaining large, repetitive YAML manifests, Helm lets you define an application once as a chart and then install, 
upgrade, or roll back it across environments with simple commands.

A Helm chart bundles all the Kubernetes resources needed for an application—such as Deployments, Services, and ConfigMaps—into a single versioned unit. 
This makes deployments more consistent, easier to reproduce, and much easier to manage at scale. Helm also supports templating, so you can parameterize 
configurations for different environments like dev, staging, and production without duplicating files.

In practice, Helm is widely used in Kubernetes ecosystems because it reduces operational complexity, improves consistency, and enables GitOps-style 
workflows where application versions and configurations are tracked and managed cleanly.


To install Helm, run the following command on all control-plane node:

.. code-block:: bash

    wget https://get.helm.sh/helm-v3.19.0-linux-amd64.tar.gz

    tar -xvf helm-v3.19.0-linux-amd64.tar.gz 

    sudo cp linux-amd64/helm /usr/local/bin/helm

.. code-block:: bash

   helm version