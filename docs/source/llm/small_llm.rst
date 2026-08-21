Small LLM Inference
===================

The ``small-llm`` Argo CD Application deploys a CPU-only Ollama inference
server and pulls ``qwen2.5:0.5b``. It is intended for functional testing, not
production inference or processing sensitive information.

Git ownership
-------------

The Application definition is
``argocd/applications/llm/01-small-llm.yaml`` at sync wave ``30``. It reads the
plain Kubernetes resources under ``llm/small-llm``:

* A ``2Gi`` ``mgmnt-sc`` PVC for the Ollama model cache.
* A single CPU-only Deployment scheduled to ``worker-type=cpu`` nodes.
* An internal ClusterIP Service on port ``11434``.
* A PostSync Job that downloads ``qwen2.5:0.5b`` through the Ollama API.

The Ollama image is pinned to version ``0.32.15`` and its Linux AMD64 image
digest. Review and update both values together when upgrading.

Deploy
------

The ``small-llm`` namespace must be permitted by the infrastructure AppProject.
On an existing cluster, apply the updated project once before Argo CD creates
the Application::

   kubectl apply -f argocd/bootstrap/01-project-infrastructure.yaml

After committing and pushing the manifests, inspect the application and model
loader::

   kubectl -n argocd get application small-llm
   kubectl -n small-llm get deployment,pod,pvc,service,job
   kubectl -n small-llm rollout status deployment/small-llm --timeout=5m
   kubectl -n small-llm logs job/small-llm-load-model

The hook Job is deleted after a successful pull. Its absence after the
Application becomes healthy is therefore expected. Confirm the cached model::

   kubectl -n small-llm port-forward service/small-llm 11434:11434

In another terminal::

   curl http://127.0.0.1:11434/api/tags

   curl http://127.0.0.1:11434/api/generate \
     -H 'Content-Type: application/json' \
     -d '{
       "model": "qwen2.5:0.5b",
       "prompt": "Explain Kubernetes in one sentence.",
       "stream": false
     }'

Security and scaling
--------------------

The Service is deliberately ClusterIP-only because the Ollama API has no
repository-configured authentication. Do not add it to the platform ingress or
expose it publicly without an authenticated proxy, TLS, request limits, and a
data-handling review.

This Deployment is not submitted to Kueue. Kueue controls queued Jobs, while
the inference server is a continuously running service. GPU acceleration
should be added only after the NVIDIA device plugin exposes ``nvidia.com/gpu``
resources and the selected Ollama image is pinned for the GPU runtime.

Troubleshooting
---------------

If the Pod remains Pending, verify the CPU node label and PVC::

   kubectl get nodes -l worker-type=cpu
   kubectl -n small-llm describe pod -l app.kubernetes.io/name=small-llm
   kubectl -n small-llm get pvc small-llm-model-cache

If the model pull fails, inspect the hook while it is running and confirm the
cluster can reach the Ollama model registry::

   kubectl -n small-llm get jobs,pods
   kubectl -n small-llm logs -l app.kubernetes.io/component=model-loader
