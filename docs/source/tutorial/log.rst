Logging and Debugging
========================

Logging is a critical aspect of debugging and monitoring applications running in Kubernetes. Understanding how to access and interpret logs can help 
you identify issues and ensure your applications are running smoothly.


.. note::

    Kubernetes does **not require systemd**, but most standard Linux clusters use it to manage kubelet and other node services.

    In simpler terms:

    * **With systemd (most common):** kubelet runs as a systemd service and logs are accessed via `journalctl`.
    * **Without systemd:** kubelet can run using other init systems (like OpenRC, runit), lightweight OS setups, or even as a manually started process.
    * **Special Kubernetes OSes (like k3s, Bottlerocket, Flatcar):** may reduce or hide systemd usage, but still rely on some process supervisor underneath.


    Systemd is just the **default service manager**, not a Kubernetes requirement.


.. code-block:: bash

    journalctl -u kubelet |less


.. note::

    jourbalctl is a command-line utility for querying and displaying logs from systemd services. The `-u kubelet` option filters the logs to show 
    only those related to the kubelet service, which is responsible for managing pods and containers on each node in a Kubernetes cluster. 


Most core Kubernetes components now run as containers, so you can inspect them either from the container level or by viewing their pods. 

.. code-block:: bash

    kubectl logs -n kube-system -l k8s-app=kubelet

.. code-block:: bash

    sudo find / -name "*apiserver*log"
    
    /var/log/containers/kube-apiserver-ip-172-31-17-15_kube-system_kube-apiserver-6e6ae5c744e4d82afe911b4438a61ce8f4c868528bba87e577f0945098fc1a2c.log
    /var/log/containers/kube-apiserver-ip-172-31-17-15_kube-system_kube-apiserver-4bb6512aab6dca5aaee1208216055bcbf21fd57897842dd4a47773d8423a1701.log

    