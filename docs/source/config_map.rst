Config Map
==========

A ConfigMap is a Kubernetes API object that allows you to store non-confidential data in key-value pairs. It is used to decouple configuration 
artifacts from image content to keep containerized applications portable. ConfigMaps can be consumed as environment variables, 
command-line arguments, or as configuration files in a volume.

.. code-block:: bash

    mkdir primary
    echo c > primary/cyan
    echo m > primary/magenta
    echo y > primary/yellow
    echo k > primary/black
    echo "known as key" >> primary/black
    echo blue > favorite

Now create the ConfigMap using the `kubectl create configmap` command:

.. code-block:: bash

    kubectl create configmap colors \
        --from-literal=text=black \
        --from-file=./favorite \
        --from-file=./primary/

    configmap/colors created



The command `kubectl create configmap colors --from-literal=text=black --from-file=./favorite --from-file=./primary/` creates a Kubernetes 
ConfigMap named `colors` using multiple data sources. The `--from-literal` option adds a direct key-value pair (`text=black`), the single 
`--from-file` option adds one file where the filename becomes the key and the file contents become the value, and the directory-based 
`--from-file=./primary/` loads all files in the directory into the ConfigMap, with each filename used as a separate key. The resulting 
ConfigMap can then be used by Pods as configuration data through environment variables or mounted files.


.. code-block:: bash

    kubectl get configmaps

    NAME               DATA   AGE
    colors             6      98s
    kube-root-ca.crt   1      92d


.. code-block:: bash

     kubectl get configmap colors

    NAME     DATA   AGE
    colors   6      106s

.. code-block:: bash

    apiVersion: v1
    data:
      black: |
        k
        known as key
      cyan: |
        c
      favorite: |
        blue
      magenta: |
        m
      text: black
      yellow: |
        y
    kind: ConfigMap
    metadata:
      creationTimestamp: "2026-05-20T00:24:38Z"
      name: colors
      namespace: default
      resourceVersion: "12041916"
      uid: 27f32003-8f83-418c-8af4-dbf8fb272be1


Now create a file `simpleshell.yaml` with the following content:

.. code-block:: yaml

    apiVersion: v1
    kind: Pod
    metadata:
      name: shell-demo

    spec:
      containers:
        - name: nginx
          image: nginx
          env:
            - name: ilike
              valueFrom:
                configMapKeyRef:
                  name: colors
                  key: favorite


This YAML file defines a Kubernetes Pod named `shell-demo` running an `nginx` container. The container sets an environment variable called `ilike` 
by reading the `favorite` key from the `colors` ConfigMap using `configMapKeyRef`. This allows configuration data stored in the ConfigMap to be 
injected into the container as an environment variable.

Now apply the Pod definition and check the environment variable:

.. code-block:: bash

    kubectl apply -f simpleshell.yaml

    pod/shell-demo created
    


.. code-block:: bash

    kubectl exec shell-demo -- /bin/bash -c 'echo $ilike'

    blue

Now delete the Pod:

.. code-block:: bash

    kubectl delete pod shell-demo


Now change the `simpleshell.yaml` with the following content:

.. code-block:: bash

    apiVersion: v1
    kind: Pod
    metadata:
      name: shell-demo

    spec:
      containers:
        - name: nginx
          image: nginx

          env:
            - name: ilike
              valueFrom:
                configMapKeyRef:
                  name: colors
                  key: favorite

          envFrom:
            - configMapRef:
                name: colors


`envFrom` in Kubernetes is used to import all key-value pairs from a ConfigMap or Secret as environment variables inside a container. Instead of 
defining each variable individually with `env`, `envFrom` automatically loads every entry from the referenced ConfigMap.

Now apply the Pod definition and check the environment variables:

.. code-block:: bash

    kubectl apply -f simpleshell.yaml

    pod/shell-demo created


.. code-block:: bash

    kubectl exec shell-demo -- /bin/bash -c 'env'

    black=k
    known as key

    KUBERNETES_SERVICE_PORT_HTTPS=443
    cyan=c

    yellow=y

    KUBERNETES_SERVICE_PORT=443
    HOSTNAME=shell-demo
    ilike=blue

    PWD=/
    ACME_VERSION=0.4.1
    PKG_RELEASE=1~trixie
    HOME=/root
    KUBERNETES_PORT_443_TCP=tcp://10.96.0.1:443
    DYNPKG_RELEASE=1~trixie
    text=black
    NJS_VERSION=0.9.9
    favorite=blue

    SHLVL=0
    KUBERNETES_PORT_443_TCP_PROTO=tcp
    KUBERNETES_PORT_443_TCP_ADDR=10.96.0.1
    KUBERNETES_SERVICE_HOST=10.96.0.1
    KUBERNETES_PORT=tcp://10.96.0.1:443
    KUBERNETES_PORT_443_TCP_PORT=443
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
    NGINX_VERSION=1.31.0
    NJS_RELEASE=1~trixie
    magenta=m


.. code-block:: bash

    kubectl delete pod shell-demo

Now create another file `car-map.yaml` with the following content:

.. code-block:: yaml

    apiVersion: v1
    kind: ConfigMap

    metadata:
      name: fast-car
      namespace: default

    data:
      car.make: Ford
      car.model: Mustang
      car.trim: Shelby


.. code-block:: bash

    kubectl apply -f car-map.yaml

    configmap/fast-car created


.. code-block:: bash

    kubectl get configmaps

    NAME               DATA   AGE
    colors             6      51m
    fast-car           3      17m
    kube-root-ca.crt   1      92d


.. code-block:: bash

    apiVersion: v1
    data:
      car.make: Ford
      car.model: Mustang
      car.trim: Shelby
    kind: ConfigMap
    metadata:
      creationTimestamp: "2026-05-20T00:58:47Z"
      name: fast-car
      namespace: default
      resourceVersion: "12045038"
      uid: c0439849-547e-4882-bdad-84535d74a580


Now lest malke this configmap available as a violume in a Pod. Rewrite the  file `simpleshell.yaml` with the following content:

.. code-block:: bash
    
   
    apiVersion: v1
    kind: Pod

    metadata:
      name: shell-demo

    spec:
      containers:
        - name: nginx
          image: nginx

          volumeMounts:
            - name: car-vol
              mountPath: /etc/cars

      volumes:
        - name: car-vol
          configMap:
            name: fast-car


.. note::
    
    * `volumes` creates a volume at the Pod level

    * `volumeMounts` mounts that volume into the container at the specified path. 


In this case the continer will have a mount at `/etc/cars` with 3 files, `car.make`, `car.model`, and `car.trim` with the content of `Ford`, `Mustang`, 
and `Shelby` respectively.

.. code-block:: bash
    
    kubectl apply -f simpleshell.yaml

    pod/shell-demo created

.. code-block:: bash

    kubectl exec shell-demo -- /bin/bash -c 'df -ha |grep car'

    /dev/root        19G   16G  3.2G  83% /etc/cars


.. code-block:: bash

    kubectl exec shell-demo -- /bin/bash -c 'ls /etc/cars'

    car.make
    car.model
    car.trim

.. code-block:: bash
    
    kubectl exec shell-demo -- /bin/bash -c 'cat /etc/cars/car.make'

    Ford


Now delete the Pod and the ConfigMap:

.. code-block:: bash

    kubectlctl delete pods shell-demo

    kubectl delete configmap fast-car colors

