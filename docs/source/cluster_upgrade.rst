Cluster Upgade
================

First, update the package index on your system to ensure you have the latest information about available packages and their versions. 
This is an important step before performing any upgrades or installations.


.. code-block:: bash

    sudo apt update


Find the installed kubernetes version

.. code-block:: bash

    kubectl version

Now updates your system's Kubernetes package source from version 1.33 to 1.34 by modifying the APT repository file.

.. code-block:: bash

    sudo sed -i 's/v1.34/v1.35/g' /etc/apt/sources.list.d/kubernetes.list

    sudo apt-get update

View the available kubernetes packages.

.. code-block:: bash

    sudo apt-cache madison kubeadm

    kubeadm | 1.35.4-1.1 | https://pkgs.k8s.io/core:/stable:/v1.35/deb  Packages
    kubeadm | 1.35.3-1.1 | https://pkgs.k8s.io/core:/stable:/v1.35/deb  Packages
    kubeadm | 1.35.2-1.1 | https://pkgs.k8s.io/core:/stable:/v1.35/deb  Packages
    kubeadm | 1.35.1-1.1 | https://pkgs.k8s.io/core:/stable:/v1.35/deb  Packages
    kubeadm | 1.35.0-1.1 | https://pkgs.k8s.io/core:/stable:/v1.35/deb  Packages


When we installed kubernetes packages we marked them as "hold" to prevent them from being automatically updated. 
This is a common practice to avoid unintended upgrades that could potentially disrupt the cluster. 

.. code-block:: bash

    sudo apt-mark showhold

Now that we have verified the available versions, we can proceed to unhold the kubeadm package so that it can be upgraded.

.. code-block:: bash

    sudo apt-mark unhold kubeadm


Now we can upgrade kubeadm to the latest version.

.. code-block:: bash

    sudo apt-get install -y kubeadm=1.35.4-1.1


Hold the package again to prevent updates along with other software.

.. code-block:: bash

    sudo apt-mark hold kubeadm

    sudo kubeadm version


.. important::

    The above steps only upgrades the tool (kubeadm) used to perform the upgrade. This does NOT upgrade your Kubernetes cluster itself.



To prepare the control plane node for update we first need to evict as many pods as possible. At the same time, we have system-critical 
pods (DaemonSets) running. So first find the nodes that are running the control plane components and then drain them one by one.

.. code-block:: bash

    kubectl get nodes -o wide

    NAME               STATUS   ROLES           AGE   VERSION
    ip-172-31-17-15    Ready    control-plane   73d   v1.34.4
    ip-172-31-29-155   Ready    <none>          73d   v1.34.4
    ip-172-31-31-226   Ready    <none>          73d   v1.34.4

Now we can drain the control plane node. This will evict all the pods running on the node, except for the ones that are part of DaemonSets.


.. code-block:: bash

    kubectl drain ip-172-31-17-15 --ignore-daemonsets

    node/ip-172-31-17-15 cordoned
    Warning: ignoring DaemonSet-managed Pods: kube-system/calico-node-t75zw, kube-system/kube-proxy-ffv5v
    evicting pod kube-system/coredns-66bc5c9577-rs77q
    evicting pod kube-system/calico-kube-controllers-6fd9cc49d6-26g4l
    evicting pod kube-system/coredns-66bc5c9577-f2gkh
    pod/calico-kube-controllers-6fd9cc49d6-26g4l evicted
    pod/coredns-66bc5c9577-rs77q evicted
    pod/coredns-66bc5c9577-f2gkh evicted
    node/ip-172-31-17-15 drained

Now find the upgrade plan for the control plane node. This will show you the components that need to be upgraded and their current and target versions.

.. code-block:: bash

    sudo kubeadm upgrade plan

    [preflight] Running pre-flight checks.
    [upgrade/config] Reading configuration from the "kubeadm-config" ConfigMap in namespace "kube-system"...
    [upgrade/config] Use 'kubeadm init phase upload-config kubeadm --config your-config-file' to re-upload it.
    [upgrade] Running cluster health checks
    [upgrade] Fetching available versions to upgrade to
    [upgrade/versions] Cluster version: 1.34.4
    [upgrade/versions] kubeadm version: v1.35.4
    I0501 03:09:25.040115 4006412 version.go:260] remote version is much newer: v1.36.0; falling back to: stable-1.35
    [upgrade/versions] Target version: v1.35.4
    [upgrade/versions] Latest version in the v1.34 series: v1.34.7

    Components that must be upgraded manually after you have upgraded the control plane with 'kubeadm upgrade apply':
    COMPONENT   NODE               CURRENT   TARGET
    kubelet     ip-172-31-17-15    v1.34.4   v1.34.7
    kubelet     ip-172-31-29-155   v1.34.4   v1.34.7
    kubelet     ip-172-31-31-226   v1.34.4   v1.34.7

    Upgrade to the latest version in the v1.34 series:

    COMPONENT                 NODE              CURRENT   TARGET
    kube-apiserver            ip-172-31-17-15   v1.34.4   v1.34.7
    kube-controller-manager   ip-172-31-17-15   v1.34.4   v1.34.7
    kube-scheduler            ip-172-31-17-15   v1.34.4   v1.34.7
    kube-proxy                                  1.34.4    v1.34.7
    CoreDNS                                     v1.12.1   v1.13.1
    etcd                      ip-172-31-17-15   3.6.5-0   3.6.6-0

    You can now apply the upgrade by executing the following command:

            kubeadm upgrade apply v1.34.7

    _____________________________________________________________________

    Components that must be upgraded manually after you have upgraded the control plane with 'kubeadm upgrade apply':
    COMPONENT   NODE               CURRENT   TARGET
    kubelet     ip-172-31-17-15    v1.34.4   v1.35.4
    kubelet     ip-172-31-29-155   v1.34.4   v1.35.4
    kubelet     ip-172-31-31-226   v1.34.4   v1.35.4

    Upgrade to the latest stable version:

    COMPONENT                 NODE              CURRENT   TARGET
    kube-apiserver            ip-172-31-17-15   v1.34.4   v1.35.4
    kube-controller-manager   ip-172-31-17-15   v1.34.4   v1.35.4
    kube-scheduler            ip-172-31-17-15   v1.34.4   v1.35.4
    kube-proxy                                  1.34.4    v1.35.4
    CoreDNS                                     v1.12.1   v1.13.1
    etcd                      ip-172-31-17-15   3.6.5-0   3.6.6-0

    You can now apply the upgrade by executing the following command:

            kubeadm upgrade apply v1.35.4

    _____________________________________________________________________


    The table below shows the current state of component configs as understood by this version of kubeadm.
    Configs that have a "yes" mark in the "MANUAL UPGRADE REQUIRED" column require manual config upgrade or
    resetting to kubeadm defaults before a successful upgrade can be performed. The version to manually
    upgrade to is denoted in the "PREFERRED VERSION" column.

    API GROUP                 CURRENT VERSION   PREFERRED VERSION   MANUAL UPGRADE REQUIRED
    kubeproxy.config.k8s.io   v1alpha1          v1alpha1            no
    kubelet.config.k8s.io     v1beta1           v1beta1             no
    _____________________________________________________________________


.. note::

    `kubeadm upgrade plan` is only showing available upgrade paths, not performing any changes. Your cluster is still running Kubernetes v1.34.4, 
    and kubeadm is indicating that you can first do a patch upgrade to v1.34.7 or proceed to a minor upgrade to v1.35.4, but neither has been 
    applied yet. The control plane components (API server, scheduler, controller manager, etcd, CoreDNS) remain at v1.34.4 because upgrades only 
    happen after you explicitly run kubeadm upgrade apply. Kubelet is also still at v1.34.4 on all nodes because it must be upgraded manually 
    on each node after the control plane is updated. Overall, the output reflects pending upgrade steps rather than components being stuck, 
    and Kubernetes enforces this staged process to ensure safe, incremental version upgrades.

In the above plan you are given twop options for upgrading the control plane components. You can either upgrade to the latest patch version in the 
current minor version (v1.34.7) or upgrade to the latest minor version (v1.35.4). It is generally recommended to upgrade to the latest patch version 
first to ensure stability and compatibility,

.. code-block:: bash

    sudo kubeadm upgrade apply v1.34.7

But in out case we ill get an error because the kubeadm version is not compatible with the target version. \

.. code-block:: bash

    sudo kubeadm upgrade apply v1.34.7
    [upgrade] Reading configuration from the "kubeadm-config" ConfigMap in namespace "kube-system"...
    [upgrade] Use 'kubeadm init phase upload-config kubeadm --config your-config-file' to re-upload it.
    [upgrade/preflight] Running preflight checks
    [upgrade] Running cluster health checks
    [upgrade/preflight] You have chosen to upgrade the cluster version to "v1.34.7"
    [upgrade/versions] Cluster version: v1.34.4
    [upgrade/versions] kubeadm version: v1.35.4
    error: error execution phase preflight: the version argument is invalid due to these errors:

            - Kubeadm version v1.35.4 can only be used to upgrade to Kubernetes version 1.35

    Can be bypassed if you pass the --force flag
    To see the stack trace of this error execute with --v=5 or higher

This is because kubeadm v1.35.4 can only be used to upgrade to Kubernetes v1.35.x, and you are trying to upgrade to v1.34.7. 
Ideally, we should have upgraded kubeadm to v1.34.7 first, then performed the upgrade to Kubernetes v1.34.7, and then upgraded kubeadm to v1.35.4 
before upgrading to Kubernetes v1.35.4.

For the purpose of this training, we will bypass this check and proceed with the upgrade to v1.35.4.

.. code-block:: bash

    kubeadm upgrade apply v1.35.4


Check the nodes to see the current version of the control plane components. 

.. code-block:: bash

    kubectl get node

    NAME               STATUS                     ROLES           AGE   VERSION
    ip-172-31-17-15    Ready,SchedulingDisabled   control-plane   73d   v1.34.4
    ip-172-31-29-155   Ready                      <none>          73d   v1.34.4
    ip-172-31-31-226   Ready                      <none>          73d   v1.34.4

.. note::

    The upgrade succeeded only for the Kubernetes control plane, which is now at v1.35.4, but `kubectl get nodes` still shows v1.34.4 because that 
    version reflects the kubelet running on each node, not the control plane. kubeadm does not automatically upgrade kubelet, so all nodes 
    (including the control-plane node) are still running the old kubelet version. As a result, the cluster is in a partially upgraded state: 
    control plane is updated, but kubelets are not. To complete the upgrade, you must manually install and restart kubelet v1.35.4 on all nodes,
    after which `kubectl get nodes` will show the updated version.

    `Ready,SchedulingDisabled` means the node is healthy and functioning (`Ready`), but Kubernetes has intentionally blocked it from receiving new 
    pods (`SchedulingDisabled`). This typically happens when the node is cordoned during maintenance or upgrades, so existing workloads can 
    continue running, but no new ones will be scheduled onto it until it is uncordoned.



Now release the hold on kubelet and kubectl.

.. code-block:: bash

    sudo apt-mark unhold kubelet kubectl

Then upgrade kubelet and kubectl to the latest version. First the exact version of kubelet and kubectl that is available in the package repository
can be found using the following command:

.. code-block:: bash

    apt-cache madison kubelet

    kubelet | 1.35.4-1.1 | https://pkgs.k8s.io/core:/stable:/v1.35/deb  Packages
    kubelet | 1.35.3-1.1 | https://pkgs.k8s.io/core:/stable:/v1.35/deb  Packages
    kubelet | 1.35.2-1.1 | https://pkgs.k8s.io/core:/stable:/v1.35/deb  Packages
    kubelet | 1.35.1-1.1 | https://pkgs.k8s.io/core:/stable:/v1.35/deb  Packages
    kubelet | 1.35.0-1.1 | https://pkgs.k8s.io/core:/stable:/v1.35/deb  Packages


    sudo apt-cache madison kubectl

    kubectl | 1.35.4-1.1 | https://pkgs.k8s.io/core:/stable:/v1.35/deb  Packages
    kubectl | 1.35.3-1.1 | https://pkgs.k8s.io/core:/stable:/v1.35/deb  Packages
    kubectl | 1.35.2-1.1 | https://pkgs.k8s.io/core:/stable:/v1.35/deb  Packages
    kubectl | 1.35.1-1.1 | https://pkgs.k8s.io/core:/stable:/v1.35/deb  Packages
    kubectl | 1.35.0-1.1 | https://pkgs.k8s.io/core:/stable:/v1.35/deb  Packages

Now that we have confirmed that the package avaialble is same as the target version, we can proceed to upgrade kubelet and kubectl.

.. code-block:: bash

    sudo apt-get install -y kubelet=1.35.4-1.1 kubectl=1.35.4-1.1


Now re-instate the hold on the packages and restart the daemons

.. code-block:: bash

    sudo apt-mark hold kubelet kubectl

    sudo systemctl daemon-reload
    sudo systemctl restart kubelet


Now if we check the nodes again, we will see that the kubelet version is now updated to v1.35.4.

.. code-block:: bash

    kubectl get nodes

    NAME               STATUS                     ROLES           AGE   VERSION
    ip-172-31-17-15    Ready,SchedulingDisabled   control-plane   73d   v1.35.4
    ip-172-31-29-155   Ready                      <none>          73d   v1.34.4
    ip-172-31-31-226   Ready                      <none>          73d   v1.34.4


You can see that the CP nodes are now upgraded to v1.35.4 while the worker nodes are still on v1.34.4. 

Now we can uncordon the control plane node to allow scheduling of new pods.

.. code-block:: bash

    kubectl uncordon ip-172-31-17-15

    node/ip-172-31-17-15 uncordoned

.. code-block:: bash

    kubectl get nodes

    NAME               STATUS   ROLES           AGE   VERSION
    ip-172-31-17-15    Ready    control-plane   73d   v1.35.4
    ip-172-31-29-155   Ready    <none>          73d   v1.34.4
    ip-172-31-31-226   Ready    <none>          73d   v1.34.4

Now we can proceed to upgrade the worker nodes one by one. 

.. important::

    We have to login to the worker nodes and perform the upgrade manually because kubeadm does not support upgrading worker nodes remotely.


.. code-block:: bash

    sudo apt-mark unhold kubeadm

    sudo sed -i 's/v1.34/v1.35/g' /etc/apt/sources.list.d/kubernetes.list

    sudo apt-get update

    sudo apt-cache madison kubeadm

    sudo apt-get install -y kubeadm=1.35.4-1.1

    sudo apt-mark hold kubeadm


Now from the **control plane node**, we can drain the worker node to evict all the pods running on it.

.. code-block:: bash

    kubectl drain ip-172-31-29-155   --ignore-daemonsets

    node/ip-172-31-29-155 cordoned
    Warning: ignoring DaemonSet-managed Pods: kube-system/calico-node-fqxdm, kube-system/kube-proxy-psbz7
    evicting pod kube-system/coredns-7d764666f9-rjf8v
    evicting pod kube-system/calico-kube-controllers-6fd9cc49d6-2s5jh
    evicting pod kube-system/coredns-7d764666f9-26tkt
    pod/calico-kube-controllers-6fd9cc49d6-2s5jh evicted
    pod/coredns-7d764666f9-rjf8v evicted
    pod/coredns-7d764666f9-26tkt evicted
    node/ip-172-31-29-155 drained

.. code-block:: bash

    kubectl get nodes

    NAME               STATUS                     ROLES           AGE   VERSION
    ip-172-31-17-15    Ready                      control-plane   73d   v1.35.4
    ip-172-31-29-155   Ready,SchedulingDisabled   <none>          73d   v1.34.4
    ip-172-31-31-226   Ready                      <none>          73d   v1.34.4


Now back on the **worker node**, do the following

.. code-block:: bash

    sudo kubeadm upgrade node

    [upgrade] Reading configuration from the "kubeadm-config" ConfigMap in namespace "kube-system"...
    [upgrade] Use 'kubeadm init phase upload-config kubeadm --config your-config-file' to re-upload it.
    [upgrade/preflight] Running pre-flight checks
    [upgrade/preflight] Skipping prepull. Not a control plane node.
    [upgrade/control-plane] Skipping phase. Not a control plane node.
    [upgrade/kubeconfig] Skipping phase. Not a control plane node.
    W0501 04:18:07.274280 1249631 postupgrade.go:105] Using temporary directory /etc/kubernetes/tmp/kubeadm-kubelet-config-2026-05-01-04-18-07 for kubelet config. To override it set the environment variable KUBEADM_UPGRADE_DRYRUN_DIR
    [upgrade] Backing up kubelet config file to /etc/kubernetes/tmp/kubeadm-kubelet-config-2026-05-01-04-18-07/config.yaml
    [patches] Applied patch of type "application/strategic-merge-patch+json" to target "kubeletconfiguration"
    [kubelet-start] Writing kubelet configuration to file "/var/lib/kubelet/config.yaml"
    [upgrade/kubelet-config] The kubelet configuration for this node was successfully upgraded!
    [upgrade/addon] Skipping the addon/coredns phase. Not a control plane node.
    [upgrade/addon] Skipping the addon/kube-proxy phase. Not a control plane node.
    W0501 04:18:07.291028 1249631 postupgrade.go:203] Using temporary directory /etc/kubernetes/tmp/kubeadm-kubelet-env4108424708 for kubelet env file. To override it set the environment variable KUBEADM_UPGRADE_DRYRUN_DIR
    [upgrade] Backing up kubelet env file to /etc/kubernetes/tmp/kubeadm-kubelet-env4108424708/kubeadm-flags.env
    [kubelet-start] Writing kubelet environment file with flags to file "/var/lib/kubelet/kubeadm-flags.env"


.. note::

    Worker nodes only need kubeadm upgrade node because they don't run control plane components like the API server or etcd. 
    This command only updates node-level configuration so the worker can communicate with the upgraded cluster. It does not upgrade 
    kubelet or other binaries—that must be done manually. In contrast, control plane nodes require kubeadm upgrade apply because they 
    host the core cluster components.



Now we continue with the installatinons on the **worker node** to upgrade kubelet and kubectl to the latest version.


.. code-block:: bash

    sudo apt-mark unhold kubelet kubectl

    sudo apt-get install -y kubelet=1.35.4-1.1 kubectl=1.35.4-1.1

    sudo apt-mark hold kubelet kubectl
    
    sudo systemctl daemon-reload

    sudo systemctl restart kubelet

    


Now check the status of the nodes again from the **control plane node**.

.. code-block:: bash


    kubectl get nodes

    NAME               STATUS                     ROLES           AGE   VERSION
    ip-172-31-17-15    Ready                      control-plane   73d   v1.35.4
    ip-172-31-29-155   Ready,SchedulingDisabled   <none>          73d   v1.35.4
    ip-172-31-31-226   Ready                      <none>          73d   v1.34.4

    

.. code-block:: bash

    kubectl uncordon ip-172-31-29-155

    kubectl get nodes

    NAME               STATUS   ROLES           AGE   VERSION
    ip-172-31-17-15    Ready    control-plane   73d   v1.35.4
    ip-172-31-29-155   Ready    <none>          73d   v1.35.4
    ip-172-31-31-226   Ready    <none>          73d   v1.34.4



Now we can repeat the same steps for the all worker node to complete the upgrade of the cluster.

Finally check the status of the nodes again from the **control plane node**, and you should see that all the nodes are now running the latest version 
of Kubernetes.

.. code-block:: bash

    kubectl get nodes
    
    NAME               STATUS   ROLES           AGE   VERSION
    ip-172-31-17-15    Ready    control-plane   73d   v1.35.4
    ip-172-31-29-155   Ready    <none>          73d   v1.35.4
    ip-172-31-31-226   Ready    <none>          73d   v1.35.4

