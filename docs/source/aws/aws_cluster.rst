AWS cluster provisioning
========================

The active AWS cluster design uses Terraform and Talos Linux exclusively.
Talos nodes have no SSH service and are not configured with Ansible, kubeadm,
HAProxy, or host package-management playbooks.

Follow :doc:`../talos` for the complete procedure, including:

* selecting the Talos AWS AMIs;
* reserving the Kubernetes API Elastic IP;
* generating one shared Talos configuration bundle;
* synchronizing sensitive HCP Terraform variables;
* applying Terraform and bootstrapping etcd exactly once;
* using the public Talos endpoint with private node targets;
* rendering environment-specific manifests from the ingress Elastic IP; and
* installing Argo CD with Helm after the cluster becomes healthy.

The former SSH, kubeadm, Calico, HAProxy, and Ansible workflow is retired and
must not be used against Talos instances.
