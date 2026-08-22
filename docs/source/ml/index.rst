ML Workload Access
==================

This section documents the HPC-style access model used to submit Kubeflow
Trainer workloads through Kueue. Users connect to the login node with an
individual Linux account and use a restricted Kubernetes identity in the
``mlproject`` namespace.

.. toctree::
   :maxdepth: 1

   login_node_user_onboarding
   kubeflow_job_submission
   persistent_training_and_tracing
   instrumenting_trainjobs_with_opentelemetry
