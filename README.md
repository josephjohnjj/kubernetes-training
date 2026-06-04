# Kubernetes Training

This repository covers the fundamentals of Kubernetes along with infrastructure-as-code to provision a production-ready cluster.


## Kubernetes Cluster Components

├── Infrastructure / Provisioning
│   ├── HCP
│   ├── Terraform
│   └── Ansible
│
├── Cluster Core / Node Runtime
│   ├── containerd.io
│   └── Calico
│
├── Storage
│   └── Rook
│       └── Ceph
│
├── Kubernetes Platform / Controllers
│   ├── Metrics Server (kubectl top, HPA)
│   └── Prometheus (monitoring & alerting)
│
├── Workload Orchestration / AI & Batch Layer
│   ├── Kueue
│   └── Kubeflow
│
├── Deployment / GitOps
│   ├── Helm
│   └── Argo CD
│
└── Observability
    ├── Logs
    │   ├── Fluent Bit / Fluentd
    │   ├── Elasticsearch / OpenSearch
    │   └── Kibana
    │
    ├── Metrics
    │   ├── Metrics Server
    │   └── Prometheus
    │
    ├── Traces
    │   └── Jaeger
    │
    └── Unified Dashboard
        └── Grafana


