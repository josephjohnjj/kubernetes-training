Helm
=======

In the previous sections, we have set up a Kubernetes cluster and deployed applications using `kubectl`. However, as the number of applications and 
their dependencies grow, managing them using `kubectl` can become cumbersome. This is where Helm comes in. It is a package manager for Kubernetes 
that allows you to easily deploy and manage applications on your cluster.


A Chart is a collection of files to deploy an application. There is a good starting repo available on `https://github.com/
kubernetes/charts/tree/master/stable`, provided by vendors, or you can make your own. Search the current Charts in
the Helm Hub or an instance of Monocular for available stable databases. Repos change often, so the following output
may be different from what you see.

.. code-block:: bash

    helm search hub database

    URL                                                     CHART VERSION                   APP VERSION                     DESCRIPTION                                       
    https://artifacthub.io/packages/helm/osc/database       0.16.1                          0.1.0                           OSC database service Helm Chart                   
    https://artifacthub.io/packages/helm/eoc-charts...      0.1.0                           1.16.0                          A Helm chart for Kubernetes                       
    https://artifacthub.io/packages/helm/mongodb-he...      1.13.0                                                          MongoDB Kubernetes Enterprise Database.           



.. code-block:: bash

    helm repo add ealenn https://ealenn.github.io/charts

    "ealenn" has been added to your repositories

.. code-block:: bash

    helm repo update

    Hang tight while we grab the latest from your chart repositories...
    ...Successfully got an update from the "ealenn" chart repository
    Update Complete. ⎈Happy Helming!⎈

The `helm upgrade` command is used to upgrade a release to a new version of a chart. It allows you to update the configuration of an existing release,
or to install a new release if one does not already exist. The `--install` or `-i` flag can be used to automatically install the release if it does not already
exist.

.. code-block:: bash

    helm upgrade -i tester ealenn/echo-server --debug

.. note::
    
    In the above command, `tester` is the name of the release, `ealenn/echo-server` is the name of the chart being upgraded or installed, and 
    `--debug` is a flag that enables debug output for the command.  This can be useful for troubleshooting issues during the upgrade or 
    installation process. The `-i` flag ensures that if the release does not already exist, it will be installed instead of upgraded.


.. code-block:: bash

    kubectl get deploy,pods,svc -o wide

    NAME                                 READY   UP-TO-DATE   AVAILABLE   AGE   CONTAINERS    IMAGES                    SELECTOR
    deployment.apps/tester-echo-server   1/1     1            1           84s   echo-server   ealen/echo-server:0.6.0   app.kubernetes.io/instance=tester,app.kubernetes.io/name=echo-server

    NAME                                     READY   STATUS    RESTARTS   AGE   IP                NODE               NOMINATED NODE   READINESS GATES
    pod/tester-echo-server-948b4555f-bvc7g   1/1     Running   0          84s   192.168.214.189   ip-172-31-31-226   <none>           <none>

    NAME                         TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE   SELECTOR
    service/kubernetes           ClusterIP   10.96.0.1       <none>        443/TCP   89d   <none>
    service/tester-echo-server   ClusterIP   10.98.115.195   <none>        80/TCP    84s   app.kubernetes.io/instance=tester,app.kubernetes.io/name=echo-server


Check the service using the `curl` command:

.. code-block:: bash
    
    curl 10.98.115.195

You can list all the releases in your cluster using the `helm list` command:

.. code-block:: bash

    helm list

    NAME    NAMESPACE       REVISION        UPDATED                                 STATUS          CHART                   APP VERSION
    tester  default         1               2026-05-17 10:48:25.12049832 +0000 UTC  deployed        echo-server-0.5.0       0.6.0

You can also uninstall a release using the `helm uninstall` command:

.. code-block:: bash

    helm uninstall tester

    release "tester" uninstalled

.. code-block:: bash

    helm list

    NAME    NAMESPACE       REVISION        UPDATED STATUS  CHART   APP VERSION


You can find the downloaded charts in the `~/.cache/helm/repository` directory. 

.. code-block:: bash

    find $HOME -name *echo*

    /home/ubuntu/.cache/helm/repository/echo-server-0.5.0.tgz

You can also use the `helm pull` command to download a chart without installing it:

.. code-block:: bash

    helm pull ealenn/echo-server --untar

.. code-block:: bash

    helm fetch ealenn/echo-server --untar

