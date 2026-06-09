Persistent Volume Claim (PVC)
===================================

In the previous section, we created a Persistent Volume (PV) that points to an NFS share. Now we will create a Persistent Volume Claim (PVC) that 
will allow us to use this PV in our applications.

Create a PVC by defining it in a YAML file `pvc.yaml`:

.. code-block:: yaml

    apiVersion: v1
    kind: PersistentVolumeClaim

    metadata:
      name: pvc-one

    spec:
      accessModes:
        - ReadWriteMany

      resources:
        requests:
          storage: 200Mi


.. code-block:: bash

    kubectl create -f pvc.yaml

    persistentvolumeclaim/pvc-one created


.. code-block:: bash


    kubectl get pvc

    NAME      STATUS   VOLUME    CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
    pvc-one   Bound    pvvol-1   1Gi        RWX                           <unset>                 23s

.. code-block:: bash

    kubectl get pv
    NAME      CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM             STORAGECLASS   VOLUMEATTRIBUTESCLASS   REASON   AGE
    pvvol-1   1Gi        RWX            Retain           Bound    default/pvc-one                  <unset>                          10m


Now lets create a Deployment that uses this PV to store data. The Deployment will be defined in a YAML file `nfs-pod.yaml`:

.. code-block:: yaml

    apiVersion: apps/v1
    kind: Deployment

    metadata:
      name: nginx-nfs
      namespace: default

      annotations:
        deployment.kubernetes.io/revision: "1"

      labels:
        run: nginx

    spec:
      replicas: 1

      selector:
        matchLabels:
          run: nginx

      strategy:
        type: RollingUpdate

        rollingUpdate:
          maxSurge: 1
          maxUnavailable: 1

      template:
        metadata:
          labels:
            run: nginx

        spec:
          containers:
            - name: nginx
              image: nginx
              imagePullPolicy: Always

              ports:
                - containerPort: 80
                  protocol: TCP

              volumeMounts:
                - name: nfs-vol
                  mountPath: /opt

          volumes:
            - name: nfs-vol
              persistentVolumeClaim:
                claimName: pvc-one

          dnsPolicy: ClusterFirst
          restartPolicy: Always
          schedulerName: default-scheduler
          terminationGracePeriodSeconds: 30


Here, we are creating a Deployment that defines a volume named `nfs-vol` that is using a PersistentVolumeClaim named `pvc-one`. This setup allows the
`nginx` container to use the NFS share for persistent storage, and any data written to `/opt` in the container will be stored on the NFS server.

.. code-block:: bash

    kubectl apply -f nfs-pod.yaml

    deployment.apps/nginx-nfs created

.. code-block:: bash

    kubectl get deploy
    
    NAME        READY   UP-TO-DATE   AVAILABLE   AGE
    nginx-nfs   1/1     1            1           64s

.. code-block:: bash

    kubectl get pods

    NAME                         READY   STATUS    RESTARTS   AGE
    nginx-nfs-6bc46bfdbf-4g6df   1/1     Running   0          35s

.. code-block:: bash

    kubectl exec nginx-nfs-6bc46bfdbf-4g6df  -- /bin/bash -c 'ls /opt'

    hello.txt

.. code-block:: bash

    kubectl describe pod  nginx-nfs-6bc46bfdbf-4g6df

    ...
    ...

    Containers:
    nginx:
      Container ID:   containerd://4be9837166d7a29d91a32db51c45d84bd8438552dbcd9357ba2e7514cd84a31b
      Image:          nginx
      Image ID:       docker.io/library/nginx@sha256:206a753092e3db9fc0c5c1f295fee35f0c298c23bd015032db5faa23910318bf
      Port:           80/TCP
      Host Port:      0/TCP
      State:          Running
        Started:      Wed, 20 May 2026 03:09:50 +0000
      Ready:          True
      Restart Count:  0
      Environment:    <none>
      Mounts:
        /opt from nfs-vol (rw)
        /var/run/secrets/kubernetes.io/serviceaccount from kube-api-access-9t454 (ro)

    ...
    ...


    Volumes:
    nfs-vol:
      Type:       PersistentVolumeClaim (a reference to a PersistentVolumeClaim in the same namespace)
      ClaimName:  pvc-one
      ReadOnly:   false


Delete the resources we created:

.. code-block:: bash

    kubectl delete deploy nginx-nfs
    kubectl delete pvc pvc-one
    kubectl delete pv pvvol-1


Storage Quota
-------------

Storage Quotas are a way to limit the amount of storage resources that can be consumed by a namespace in Kubernetes. They help administrators manage 
and control the storage usage of applications running in the cluster. A Storage Quota can limit the number of Persistent Volume Claims (PVCs) and 
the total amount of storage that can be requested by those PVCs.


To create a Storage Quota, you can define it in a YAML file `storage-quota.yaml`:

.. code-block:: yaml

    apiVersion: v1
    kind: ResourceQuota

    metadata:
      name: storagequota

    spec:
      hard:
        persistentvolumeclaims: "10"
        requests.storage: "500Mi"


First, create a new namespace for this exercise:

.. code-block:: bash
    
    kubectl create namespace small

    namespace/small created


.. code-block:: bash

    kubectl describe ns small

    Name:         small
    Labels:       kubernetes.io/metadata.name=small
    Annotations:  <none>
    Status:       Active

    No resource quota.

    No LimitRange resource.

Create the pv and pvc again, but this time in the `small` namespace:

.. code-block:: bash

    kubectl -n small create -f PVol.yaml

    kubectl -n small create -f pvc.yaml

Now create the Storage Quota in the `small` namespace:

.. code-block:: bash

    kubectl apply -f storage-quota.yaml -n small

    resourcequota/storagequota created


Now check the namespace to see the Storage Quota:

.. code-block:: bash

    kubectl describe ns small

    Name:         small
    Labels:       kubernetes.io/metadata.name=small
    Annotations:  <none>
    Status:       Active

    Resource Quotas
      Name:                   storagequota
      Resource                Used   Hard
      --------                ---    ---
      persistentvolumeclaims  1      10
      requests.storage        200Mi  500Mi

    No LimitRange resource.


.. note::

    A ResourceQuota only affects the namespace where it is created. It limits resource consumption (such as Pods, PVCs, CPU, memory, or storage) for 
    workloads running in that specific namespace and does not impact other namespaces in the cluster.


Now remove the namespace field from the `nfs-pod.yaml` so that we can pass other namespaces when creating the deployment:

.. code-block:: yaml

    apiVersion: apps/v1
    kind: Deployment

    metadata:
      name: nginx-nfs

      annotations:
        deployment.kubernetes.io/revision: "1"

      labels:
        run: nginx

    spec:
      replicas: 1

      selector:
        matchLabels:
          run: nginx

      strategy:
        type: RollingUpdate

        rollingUpdate:
          maxSurge: 1
          maxUnavailable: 1

      template:
        metadata:
          labels:
            run: nginx

        spec:
          containers:
            - name: nginx
              image: nginx
              imagePullPolicy: Always

              ports:
                - containerPort: 80
                  protocol: TCP

              volumeMounts:
                - name: nfs-vol
                  mountPath: /opt

          volumes:
            - name: nfs-vol
              persistentVolumeClaim:
                claimName: pvc-one

          dnsPolicy: ClusterFirst
          restartPolicy: Always
          schedulerName: default-scheduler
          terminationGracePeriodSeconds: 30


.. code-block:: bash

    kubectl -n small create -f nfs-pod.yaml

    deployment.apps/nginx-nfs created


.. code-block:: bash

    kubectl -n small get deploy

    NAME        READY   UP-TO-DATE   AVAILABLE   AGE
    nginx-nfs   1/1     1            1           56s


Now lets create a 300M file inside of the `/opt/sfw`

.. code-block:: bash

    sudo dd if=/dev/zero of=/opt/sfw/bigfile bs=1M count=300

    300+0 records in
    300+0 records out
    314572800 bytes (315 MB, 300 MiB) copied, 0.172599 s, 1.8 GB/s

.. note::

    The file created is independent of kubernetes.

    With NFS-backed storage, Kubernetes ResourceQuota tracks only the amount of storage requested by the PersistentVolumeClaim (PVC), 
    not the actual amount of data stored on the NFS share. So even if you create a 300MB file inside `/opt/sfw`, the quota usage 
    will not increase unless the PVC storage request itself changes.


.. code-block:: bash

    kubectl describe ns small

    Name:         small
    Labels:       kubernetes.io/metadata.name=small
    Annotations:  <none>
    Status:       Active

    Resource Quotas
      Name:                   storagequota
      Resource                Used   Hard
      --------                ---    ---
      persistentvolumeclaims  1      10
      requests.storage        200Mi  500Mi

    No LimitRange resource.


.. code-block:: bash

    du -h /opt/
    du: cannot read directory '/opt/containerd': Permission denied
    4.0K    /opt/containerd
    301M    /opt/sfw
    270M    /opt/cni/bin
    270M    /opt/cni


Lets see what happens when the deployment requests more than the quota

.. code-block:: bash

    kubectl -n small delete deploy nginx-nfs

Pods are shutdown doesn't means that the storage objects are released:

.. code-block:: bash

    kubectl describe ns small

    Name:         small
    Labels:       kubernetes.io/metadata.name=small
    Annotations:  <none>
    Status:       Active

    Resource Quotas
      Name:                   storagequota
      Resource                Used   Hard
      --------                ---    ---
      persistentvolumeclaims  1      10
      requests.storage        200Mi  500Mi

    No LimitRange resource.


Now let's delete the existing PVC

.. code-block:: bash

    NAME      STATUS   VOLUME    CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
    pvc-one   Bound    pvvol-1   1Gi        RWX                           <unset>                 19h

.. note::

    In this output, the `STATUS` value `Bound` means that the PVC `pvc-one` has successfully connected to PV named `pvvol-1`

.. code-block:: bash

    kubectl delete pvc pvc-one  -n small

    persistentvolumeclaim "pvc-one" deleted from small namespace


You can verify that the `persistentvolumeclaims` is `0` in the namespace.

.. code-block:: bash

    kubectl describe ns small

    Name:         small
    Labels:       kubernetes.io/metadata.name=small
    Annotations:  <none>
    Status:       Active

    Resource Quotas
      Name:                   storagequota
      Resource                Used  Hard
      --------                ---   ---
      persistentvolumeclaims  0     10
      requests.storage        0     500Mi

    No LimitRange resource.

.. code-block:: bash

    kubectl -n small get pv

    NAME      CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS     CLAIM           STORAGECLASS   VOLUMEATTRIBUTESCLASS   REASON   AGE
    pvvol-1   1Gi        RWX            Retain           Released   small/pvc-one                  <unset>                          19h

.. note::

    * The `RECLAIM POLICY` defines what Kubernetes should do with the PV after the PVC using it is deleted.

    * `retain` means that the actual storage is not deleted the when the PVC is removed.

    The default storage policy is to retain the storage to allow recovery of any data. Manually created persistent volumes default to 
    `Retain` unless set otherwise at creation. 


Lets recreate the PV again and then change the setting using a patch.


.. code-block:: bash

    kubectl delete pv pvvol-1

    kubectl create -f PVol.yaml

.. code-block:: bash

    kubectl patch pv pvvol-1 -p '{"spec":{"persistentVolumeReclaimPolicy":"Delete"}}'

    persistentvolume/pvvol-1 patched


.. note::

    The `spec` section in the patch defines the desired configuration change for the PV. Here, it sets 
    `persistentVolumeReclaimPolicy` to `Delete`, which tells Kubernetes to automatically clean up the underlying storage resource after 
    the associated PVC is deleted.



.. code-block:: bash

    kubectl get pv pvvol-1

    NAME      CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS      CLAIM   STORAGECLASS   VOLUMEATTRIBUTESCLASS   REASON   AGE
    pvvol-1   1Gi        RWX            Delete           Available                          <unset>                          75s




Now, lets create the PVC again,

.. code-block:: bash

    kubectl -n small create -f pvc.yaml


.. code-block:: bash

    kubectl describe ns small

    Name:         small
    Labels:       kubernetes.io/metadata.name=small
    Annotations:  <none>
    Status:       Active

    Resource Quotas
      Name:                   storagequota
      Resource                Used   Hard
      --------                ---    ---
      persistentvolumeclaims  1      10
      requests.storage        200Mi  500Mi

    No LimitRange resource.


Lets remove the storage quota:

.. code-block:: bash

    kubectl -n small get resourcequota

    NAME           REQUEST                                                       LIMIT   AGE
    storagequota   persistentvolumeclaims: 1/10, requests.storage: 200Mi/500Mi           20h

.. code-block:: bash

    kubectl -n small delete resourcequota storagequota

    resourcequota "storagequota" deleted from small namespace

.. code-block:: bash

    kubectl describe ns small

    Name:         small
    Labels:       kubernetes.io/metadata.name=small
    Annotations:  <none>
    Status:       Active

    No resource quota.

    No LimitRange resource.


Edit the `storagequota.yaml` file and lower the capacity to `100Mi`.

.. code-block:: bash

    apiVersion: v1
    kind: ResourceQuota

    metadata:
      name: storagequota

    spec:
      hard:
        persistentvolumeclaims: "10"
        requests.storage: "100Mi"


            
.. code-block:: bash

    kubectl -n small create -f storage-quota.yaml

    resourcequota/storagequota created

.. code-block:: bash

    kubectl describe ns small

    Name:         small
    Labels:       kubernetes.io/metadata.name=small
    Annotations:  <none>
    Status:       Active

    Resource Quotas
      Name:                   storagequota
      Resource                Used   Hard
      --------                ---    ---
      persistentvolumeclaims  1      10
      requests.storage        200Mi  100Mi

    No LimitRange resource.


.. note::

    * The namespace quota allows a maximum of 100Mi total requested storage.

    * But the namespace is already using 200Mi.

    This is possible because Kubernetes quotas are not retroactive. The `200Mi` PVC was created before the quota was reduced to `100Mi` 
    (or before a quota existed). Kubernetes does not remove existing resources that exceed a new quota; it only prevents future storage 
    requests that would increase usage further.



Lets create the pods again.

.. code-block:: bash

    kubectl -n small create -f nfs-pod.yaml

.. code-block:: bash

    kubectl -n small get deploy
    NAME        READY   UP-TO-DATE   AVAILABLE   AGE
    nginx-nfs   1/1     1            1           16m

.. code-block:: bash

    kubectl -n small get po
    NAME                         READY   STATUS    RESTARTS   AGE
    nginx-nfs-6bc46bfdbf-gqhzt   1/1     Running   0          16m


.. note::

    The Deployment succeeds because it is only mounting an existing PVC (`pvc-one`) and not creating new storage. Resource quotas are enforced when 
    PVCs are created or resized, not when pods use them. Your namespace is already over the storage quota (`200Mi` used vs `100Mi` allowed), 
    likely because the quota was added or reduced after the PVC was created, but Kubernetes does not remove existing resources that already 
    exceed the quota.

Lets delete the deployment and the PVC.

.. code-block:: bash

    kubectl -n small delete deploy nginx-nfs

    deployment.apps "nginx-nfs" deleted from small namespace


.. code-block:: bash

    kubectl -n small delete pvc/pvc-one

    persistentvolumeclaim "pvc-one" deleted from small namespace


.. code-block:: bash

    kubectl -n small get pv

    NAME      CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM           STORAGECLASS   VOLUMEATTRIBUTESCLASS   REASON   AGE
    pvvol-1   1Gi        RWX            Delete           Failed   small/pvc-one                  <unset>                          34m

.. note::

    The PersistentVolume `pvvol-1` has a reclaim policy of `Delete`, which means Kubernetes should automatically remove the underlying storage 
    when the PVC is deleted. However, the PV entered a `Failed` state because it uses NFS storage, and the standard NFS volume type does not 
    include a built-in deleter plugin. Kubernetes can detach the volume, but it cannot automatically delete the actual directory or storage 
    on the NFS server, unlike storage systems such as Ceph or cloud storage providers that include deletion plugins or CSI drivers.


.. code-block:: bash

    kubectl delete pv/pvvol-1


Edit the persistent volume YAML file and change the `persistentVolumeReclaimPolicy` to `Recycle`.

Now set the the LimitRange `low-resource-range.yaml`:


.. code-block:: yaml

    apiVersion: v1
    kind: LimitRange
    metadata:
      name: low-resource-range
    spec:
      limits:
        - type: Container
          default:
            cpu: "1"
            memory: "500Mi"
          defaultRequest:
            cpu: "500m"
            memory: "100Mi"


.. code-block:: bash 

    kubectl -n small create -f low-resource-range.yaml

    limitrange/low-resource-range created


.. code-block:: bash 

    kubectl describe ns small

    Name:         small
    Labels:       kubernetes.io/metadata.name=small
    Annotations:  <none>
    Status:       Active

    Resource Quotas
      Name:                   storagequota
      Resource                Used  Hard
      --------                ---   ---
      persistentvolumeclaims  0     10
      requests.storage        0     100Mi

    Resource Limits
     Type       Resource  Min  Max  Default Request  Default Limit  Max Limit/Request Ratio
     ----       --------  ---  ---  ---------------  -------------  -----------------------
     Container  cpu       -    -    500m             1              -
     Container  memory    -    -    100Mi            500Mi          -


Create the persistent volume again.

.. code-block:: bash

    kubectl -n small create -f PVol.yaml

    Warning: spec.persistentVolumeReclaimPolicy: The Recycle reclaim policy is deprecated. Instead, the recommended approach is to use dynamic provisioning.
    persistentvolume/pvvol-1 created

.. code-block:: bash

    kubectl get pv

    NAME      CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS      CLAIM   STORAGECLASS   VOLUMEATTRIBUTESCLASS   REASON   AGE
    pvvol-1   1Gi        RWX            Recycle          Available                          <unset>                          28s

If you attempt to create the persistent volume claim again, it will fail.

.. code-block:: bash

    kubectl -n small create -f pvc.yaml

    Error from server (Forbidden): error when creating "pvc.yaml": persistentvolumeclaims "pvc-one" is forbidden: exceeded quota: storagequota, requested: requests.storage=200Mi, used: requests.storage=0, limited: requests.storage=100Mi


Now if we edit the resourcequota to increase the `requests.storage` to 500Mi. Then creating a new 
PVC will work


.. code-block:: bash

    kubectl -n small edit resourcequota

    kubectl -n small create -f pvc.yaml

    kubectl -n small create -f nfs-pod.yaml


.. code-block:: bash

    kubectl describe ns small

    Name:         small
    Labels:       kubernetes.io/metadata.name=small
    Annotations:  <none>
    Status:       Active

    Resource Quotas
      Name:                   storagequota
      Resource                Used   Hard
      --------                ---    ---
      persistentvolumeclaims  1      10
      requests.storage        200Mi  500Mi

    Resource Limits
     Type       Resource  Min  Max  Default Request  Default Limit  Max Limit/Request Ratio
     ----       --------  ---  ---  ---------------  -------------  -----------------------
     Container  cpu       -    -    500m             1              -
     Container  memory    -    -    100Mi            500Mi          -


.. code-block:: bash

    kubectl -n small get pvc

    NAME      STATUS   VOLUME    CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
    pvc-one   Bound    pvvol-1   1Gi        RWX                           <unset>                 4m15s


.. code-block:: bash

    kubectl -n small get pv

    NAME      CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM           STORAGECLASS   VOLUMEATTRIBUTESCLASS   REASON   AGE
    pvvol-1   1Gi        RWX            Recycle          Bound    small/pvc-one                  <unset>                          15m


.. code-block:: bash

    kubectl -n small delete pvc pvc-one

    kubectl delete pv pvvol-1

    kubectl -n small delete resourcequota storagequota

    kubectl -n small delete limitrange low-resource-range



Dynamically provision a volume
------------------------------

A provisioner in Kubernetes is a component responsible for dynamically creating storage volumes when applications request them through Persistent 
Volume Claims (PVCs). Instead of administrators manually creating Persistent Volumes (PVs) ahead of time, the provisioner works with a StorageClass 
to automatically allocate storage from a backend system such as local disks, cloud block storage, distributed storage, or network file systems. 
This enables automated storage management, simplifies cluster operations, and allows applications to request storage on demand without needing to 
know the underlying infrastructure details.

An NFS provisioner is a specific type of Kubernetes storage provisioner that dynamically creates storage directories on an NFS server for PVCs. 
When a pod requests storage using a StorageClass configured for the NFS provisioner, the provisioner automatically creates a subdirectory on 
the shared NFS export and generates the corresponding PV for Kubernetes. This provides an easy way to offer shared ReadWriteMany (RWX) storage 
to multiple pods, making it popular for development clusters, shared datasets, CI/CD workloads, and lightweight on-premise environments. Common 
implementations include NFS Subdir External Provisioner.

We will first deploy an NFS provisioner:


.. code-block:: bash

    helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/

    "nfs-subdir-external-provisioner" has been added to your repositories

.. code-block:: bash

    helm install nfs-subdir-external-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner --set nfs.server=172.31.17.15 --set nfs.path=/opt/sfw/

    NAME: nfs-subdir-external-provisioner
    LAST DEPLOYED: Sat May 23 07:58:33 2026
    NAMESPACE: default
    STATUS: deployed
    REVISION: 1
    TEST SUITE: None


This will automatically create a storage class

.. note::

    A StorageClass in Kubernetes defines how storage should be dynamically provisioned for applications. It acts as a template that tells Kubernetes 
    which storage provisioner to use, what type of storage to create, and any configuration parameters such as performance type, reclaim policy, or 
    filesystem options. When a Persistent Volume Claim (PVC) references a StorageClass, Kubernetes automatically asks the associated provisioner to 
    create the required Persistent Volume (PV). This allows users to request storage without needing to manually manage the underlying storage 
    infrastructure.

.. code-block:: bash

     kubectl get sc

    NAME         PROVISIONER                                     RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
    nfs-client   cluster.local/nfs-subdir-external-provisioner   Delete          Immediate           true                   94s


Now lets create a PVC `pvc-sc.yaml`

.. code-block:: yaml

    apiVersion: v1
    kind: PersistentVolumeClaim
    metadata:
      name: pvc-two
    spec:
      storageClassName: nfs-client
      accessModes:
        - ReadWriteMany
      resources:
        requests:
          storage: 200Mi



.. code-block:: bash

    kubectl create -f pvc-sc.yaml

    kubectl get pvc,pv

    NAME                            STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
    persistentvolumeclaim/pvc-two   Bound    pvc-83e4c050-3d9b-4883-8e0a-57373d771417   200Mi      RWX            nfs-client     <unset>                 13s

    NAME                                                        CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM             STORAGECLASS   VOLUMEATTRIBUTESCLASS   REASON   AGE
    persistentvolume/pvc-83e4c050-3d9b-4883-8e0a-57373d771417   200Mi      RWX            Delete           Bound    default/pvc-two   nfs-client     <unset>                          13s


The PVCS automatically creates the PV using the NFS-provisioner.

Now let's create a pod that will use this volume:

.. code-block:: yaml

    apiVersion: v1
    kind: Pod
    metadata:
      name: web-server
    spec:
      containers:
        - name: web-container
          image: nginx
          volumeMounts:
            - name: nfs-volume
              mountPath: /usr/share/nginx/html

      volumes:
        - name: nfs-volume
          persistentVolumeClaim:
            claimName: pvc-two

.. code-block:: bash

    kubectl create -f  pod-sc.yaml


Now create a file and copy it to the pod.

.. code-block:: bash

    echo "Welcome to the demo of storage class" > index.html

    kubectl cp index.html web-server:/usr/share/nginx/html

.. code-block:: bash

    ls /opt/sfw/

    default-pvc-two-pvc-83e4c050-3d9b-4883-8e0a-57373d771417


.. code-block:: bash

    ls /opt/sfw/default-pvc-two-pvc-83e4c050-3d9b-4883-8e0a-57373d771417/

    index.html


Now lets delete all the deployment, PVC.


.. code-block:: bash

    kubectl delete pod web-server   
    kubectl delete pvc pvc-two


Now if we check the PV we can see that there are none.

.. note::

    As the `reclaimPolicy` is `delete` for the dynamically provisioned PV. When the PVC is deleted, the PV is also deleted. 


.. code-block:: bash

    kubectl delete pv

    error: resource(s) were provided, but no name was specified
