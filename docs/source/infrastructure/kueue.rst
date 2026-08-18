Kueue
=====

Kueue is a Kubernetes-native batch job queueing system that manages and
schedules workloads based on quotas, priorities, and cluster resource
availability. It is commonly used for ML workloads, batch processing, and
multi-tenant scheduling where fair resource sharing is required.

Installation
------------

Install Kueue using the official OCI Helm chart:

.. code-block:: bash

   helm install kueue oci://registry.k8s.io/kueue/charts/kueue \
     --version=0.18.1 \
     --namespace kueue-system \
     --create-namespace \
     --wait --timeout 300s

Node Labeling
-------------

Kueue uses node labels to match workloads with appropriate compute resources.
Label worker nodes based on their capabilities:

.. code-block:: bash

   kubectl label nodes cpu-worker1 worker-type=cpu
   kubectl label nodes cpu-worker2 worker-type=cpu
   kubectl label nodes gpu-worker1 worker-type=gpu
   kubectl label nodes gpu-worker2 worker-type=gpu

These labels are used by Kueue ``ResourceFlavor`` definitions to control
scheduling decisions.

Queue Configuration
-------------------

Create workload queues for different resource types:

.. code-block:: bash

   kubectl create -f manifests/kueue/01-cpu-queue.yaml
   kubectl create -f manifests/kueue/02-gpu-queue.yaml

These queue definitions typically include:

* ClusterQueues- Define global resource quotas and policies.
* LocalQueues- Namespace-scoped queues for workloads.
* ResourceFlavors- Map workloads to node types (CPU/GPU/etc).

Verification
------------

Check that local queues are created:

.. code-block:: bash

   kubectl get localqueues -A

Check cluster-wide queues:

.. code-block:: bash

   kubectl get clusterqueues

Check resource flavor configuration:

.. code-block:: bash

   kubectl get resourceflavors

Monitoring and Troubleshooting
------------------------------

Inspect Kueue system components:

.. code-block:: bash

   kubectl get pods -n kueue-system

View Kueue controller logs:

.. code-block:: bash

   kubectl logs -n kueue-system deployment/kueue-controller-manager

Check queue admission and workload status:

.. code-block:: bash

   kubectl get workloads -A

Concept Overview
----------------

Kueue introduces a structured scheduling model:

* **ClusterQueue**- Defines global resource quotas and policies.
* **LocalQueue**- Namespace-scoped entry point for submitting workloads.
* **ResourceFlavor**- Maps workloads to node types (CPU/GPU/etc).


Kueue separates scheduling into three layers:

* **LocalQueue (Submission Layer)**  
  Users submit jobs into a namespace-level queue. The LocalQueue simply routes
  workloads to a ClusterQueue. It does not enforce quotas itself.

* **ClusterQueue (Policy & Quota Layer)**  
  The ClusterQueue is the central controller for resource allocation. It:
  
  - Defines total available CPU/GPU/memory quotas
  - Enforces fairness across namespaces
  - Controls priority and borrowing rules
  - Decides whether a workload can be admitted

* **ResourceFlavor (Execution Placement Layer)**  
  ResourceFlavors map abstract resource requests to real node types using node
  labels (e.g., CPU or GPU nodes). Once a workload is admitted, Kueue selects
  an appropriate flavor to decide where it runs.


The full scheduling flow is:

.. code-block:: text

   Workload
      ↓
   LocalQueue (namespace entry point)
      ↓
   ClusterQueue (quota + policy decision)
      ↓
   ResourceFlavor (CPU/GPU mapping)
      ↓
   Nodes (actual execution)
