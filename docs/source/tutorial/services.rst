Services
============

Designed and managed Kubernetes Services for reliable service discovery, internal communication, and external application exposure across 
containerized workloads.


.. code-block:: bash

    kubectl create ns accounting

Let's create a yaml file for deployment `nginx-one.yaml`:

.. code-block:: yaml

    apiVersion: apps/v1

    kind: Deployment

    metadata:
      name: nginx-one
      namespace: accounting
    

      labels:
        system: secondary

    spec:
      replicas: 2

      selector:
        matchLabels:
          system: secondary

      template:
        metadata:
          labels:
            system: secondary

        spec:
          nodeSelector:
            system: secondOne

          containers:
            - name: nginx
              image: nginx:1.20.1
              imagePullPolicy: Always

              ports:
                - containerPort: 8080
                  protocol: TCP


.. code-block:: bash


    kubectl create -f nginx-one.yaml 


The status of the pods will show as `Pending`

.. code-block:: bash

    kubectl -n accounting get pods

    NAME                         READY   STATUS    RESTARTS   AGE
    nginx-one-599887bddb-5frvw   0/1     Pending   0          48s
    nginx-one-599887bddb-sb4n4   0/1     Pending   0          48s


This is because the deployment expects a set of node selectors labelled as `secondOne`



.. code-block:: bash

    kubectl -n accounting get pods


    Events:
    Type     Reason            Age    From               Message
    ----     ------            ----   ----               -------
    Warning  FailedScheduling  3m10s  default-scheduler  0/3 nodes are available: 1 node(s) had untolerated taint(s), 2 node(s) didn't match Pod's node affinity/selector. no new claims to deallocate, preemption: 0/3 nodes are available: 3 Preemption is not helpful for scheduling.

Let us label one node as `secondOne`

.. code-block:: bash

    kubectl get nodes

    NAME               STATUS   ROLES           AGE   VERSION
    ip-172-31-17-15    Ready    control-plane   98d   v1.35.4
    ip-172-31-29-155   Ready    <none>          98d   v1.35.4
    ip-172-31-31-226   Ready    <none>          98d   v1.35.4

.. code-block:: bash

    kubectl label node ip-172-31-31-226 system=secondary

    node/ip-172-31-31-226 labeled

.. code-block:: bash

    kubectl -n accounting get pods

    NAME                         READY   STATUS    RESTARTS   AGE
    nginx-one-599887bddb-5frvw   1/1     Running   0          8m26s
    nginx-one-599887bddb-sb4n4   1/1     Running   0          8m26s

.. code-block:: bash

    kubectl get nodes --show-labels

    NAME               STATUS   ROLES           AGE   VERSION   LABELS
    ip-172-31-17-15    Ready    control-plane   98d   v1.35.4   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/arch=amd64,kubernetes.io/hostname=ip-172-31-17-15,kubernetes.io/os=linux,node-role.kubernetes.io/control-plane=,node.kubernetes.io/exclude-from-external-load-balancers=
    ip-172-31-29-155   Ready    <none>          98d   v1.35.4   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/arch=amd64,kubernetes.io/hostname=ip-172-31-29-155,kubernetes.io/os=linux
    ip-172-31-31-226   Ready    <none>          98d   v1.35.4   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/os=linux,kubernetes.io/arch=amd64,kubernetes.io/hostname=ip-172-31-31-226,kubernetes.io/os=linux,system=secondOne

Now we expose the deployment

.. code-block:: bash

    kubectl -n accounting expose deployment nginx-one

    service/nginx-one exposed

.. code-block:: bash

    kubectl -n accounting get ep nginx-one

    Warning: v1 Endpoints is deprecated in v1.33+; use discovery.k8s.io/v1 EndpointSlice
    NAME        ENDPOINTS                                   AGE
    nginx-one   192.168.214.137:8080,192.168.214.138:8080   52s


Let us try the curl command to see if the deployment exposure has worked


.. code-block:: bash

    curl 192.168.214.137:8080

    curl: (7) Failed to connect to 192.168.214.137 port 8080 after 1 ms: Couldn't connect to server


While the port 8080 fail, we can see that port 80 works


.. code-block:: bash

    curl 192.168.214.137:80

    <!DOCTYPE html>
    <html>
    <head>
    <title>Welcome to nginx!</title>
    <style>
        body {
            width: 35em;
            margin: 0 auto;
            font-family: Tahoma, Verdana, Arial, sans-serif;
        }
    </style>
    </head>
    <body>
    <h1>Welcome to nginx!</h1>
    <p>If you see this page, the nginx web server is successfully installed and
    working. Further configuration is required.</p>

    <p>For online documentation and support please refer to
    <a href="http://nginx.org/">nginx.org</a>.<br/>
    Commercial support is available at
    <a href="http://nginx.com/">nginx.com</a>.</p>

    <p><em>Thank you for using nginx.</em></p>
    </body>
    </html>


The issue is a mismatch between Kubernetes configuration and what the container is actually doing. Although `containerPort: 8080` is set, this does 
not make nginx listen on that port—it only serves as metadata. In reality, nginx is running on port 80, which is why `curl` to port 80 works but 
port 8080 fails. The Kubernetes Service or Endpoints are incorrectly routing traffic to port 8080, while the application is only listening on port 80. 

To fix this, either update the Service to use `containerPort: 80`

.. code-block:: yaml
    
    apiVersion: apps/v1

    kind: Deployment

    metadata:
      name: nginx-one
      namespace: accounting
    

      labels:
        system: secondary

    spec:
      replicas: 2

      selector:
        matchLabels:
          system: secondary

      template:
        metadata:
          labels:
            system: secondary

        spec:
          nodeSelector:
            system: secondOne

          containers:
            - name: nginx
              image: nginx:1.20.1
              imagePullPolicy: Always

              ports:
                - containerPort: 80
                  protocol: TCP






.. code-block:: bash

    kubectl delete deploy nginx-one -n accounting

    kubectl create -f nginx-one.yaml


.. code-block:: bash

    kubectl -n accounting edit svc nginx-one



Now edit the service as well:

.. code-block:: yaml


      ports:
      - port: 80
        protocol: TCP
        targetPort: 80


.. code-block:: bash
    
    kubectl -n accounting get ep nginx-one

    Warning: v1 Endpoints is deprecated in v1.33+; use discovery.k8s.io/v1 EndpointSlice
    NAME        ENDPOINTS                               AGE
    nginx-one   192.168.214.141:80,192.168.214.142:80   24m



In this step, we successfully accessed the NGINX page using the internal Pod IP address. Next, we will expose the deployment using 
the `NodePort` service type. We will also assign it an easy-to-remember name and place it in the `accounting` namespace. Additionally, we 
can specify the port explicitly, which can be useful when configuring firewall rules and allowing external access.

.. code-block:: bash

  kubectl -n accounting expose deployment nginx-one --type=NodePort --name=service-lab

  service/service-lab exposed


.. note::


    The command `kubectl expose deployment nginx-one` creates a Kubernetes Service using the default `ClusterIP` type, which makes the application 
    accessible only from within the cluster. This is commonly used for internal communication between services. 
    
    In contrast, `kubectl expose deployment nginx-one --type=NodePort --name=service-lab` creates a `NodePort` Service, which exposes the 
    application externally by opening a port on every Kubernetes node. This allows users to access the application from outside the cluster 
    using the node's IP address and the allocated NodePort.


.. code-block:: bash

  kubectl -n accounting get svc

  NAME          TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)        AGE
  nginx-one     ClusterIP   10.107.194.150   <none>        80/TCP         43h
  service-lab   NodePort    10.111.139.54    <none>        80:31475/TCP   5m37s


.. code-block:: bash

  kubectl -n accounting describe service service-lab

  Name:                     service-lab
  Namespace:                accounting
  Labels:                   system=secondary
  Annotations:              <none>
  Selector:                 system=secondary
  Type:                     NodePort
  IP Family Policy:         SingleStack
  IP Families:              IPv4
  IP:                       10.111.139.54
  IPs:                      10.111.139.54
  Port:                     <unset>  80/TCP
  TargetPort:               80/TCP
  NodePort:                 <unset>  31475/TCP
  Endpoints:                192.168.214.141:80,192.168.214.142:80
  Session Affinity:         None
  External Traffic Policy:  Cluster
  Internal Traffic Policy:  Cluster
  Events:                   <none>


The port assigned for this service is `31475`. Now if we try to access the cluster using the public ip:

.. code-block:: bash

  curl ifconfig.io

  3.89.209.243


.. code-block:: bash


  curl 3.89.209.243:31475        

  <!DOCTYPE html>
  <html>
  <head>
  <title>Welcome to nginx!</title>
  <style>
      body {
          width: 35em;
          margin: 0 auto;
          font-family: Tahoma, Verdana, Arial, sans-serif;
      }
  </style>
  </head>
  <body>
  <h1>Welcome to nginx!</h1>
  <p>If you see this page, the nginx web server is successfully installed and
  working. Further configuration is required.</p>

  <p>For online documentation and support please refer to
  <a href="http://nginx.org/">nginx.org</a>.<br/>
  Commercial support is available at
  <a href="http://nginx.com/">nginx.com</a>.</p>

  <p><em>Thank you for using nginx.</em></p>
  </body>
  </html>



CoreDNS
------------


CoreDNS is the default DNS server used in Kubernetes for service discovery and name resolution within a cluster. It runs as a set of Pods 
in the `kube-system` namespace and translates service names into cluster IP addresses so that applications can communicate using DNS names 
instead of IPs. For example, it resolves names like `service-name.namespace.svc.cluster.local` by using Kubernetes service and endpoint information. 
CoreDNS also supports DNS search domains such as `accounting.svc.cluster.local`, `svc.cluster.local`, and `cluster.local`, which allow shorter 
names to be automatically expanded inside Pods.


.. code-block:: yaml

  apiVersion: v1
  kind: Pod
  metadata:
    name: ubuntu
  spec:
    containers:
      - name: ubuntu
        image: ubuntu:latest
        command: ["sleep"]
        args: ["infinity"]


.. code-block:: bash

  kubectl create -f nettools.yaml 

  pod/ubuntu created


.. code-block:: bash

  kubectl exec -it ubuntu -- /bin/bash


Now inside the container do the following:

.. code-block:: bash

  apt-get update ; apt-get install curl dnsutils -y

  dig

  ; <<>> DiG 9.20.18-1ubuntu2.1-Ubuntu <<>>
  ;; global options: +cmd
  ;; Got answer:
  ;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 62884
  ;; flags: qr rd ra; QUERY: 1, ANSWER: 13, AUTHORITY: 0, ADDITIONAL: 1

  ;; OPT PSEUDOSECTION:
  ; EDNS: version: 0, flags:; udp: 1232
  ; COOKIE: 750751229af64400 (echoed)
  ;; QUESTION SECTION:
  ;.                              IN      NS

  ;; ANSWER SECTION:
  .                       30      IN      NS      h.root-servers.net.
  .                       30      IN      NS      i.root-servers.net.
  .                       30      IN      NS      j.root-servers.net.
  .                       30      IN      NS      k.root-servers.net.
  .                       30      IN      NS      l.root-servers.net.
  .                       30      IN      NS      m.root-servers.net.
  .                       30      IN      NS      a.root-servers.net.
  .                       30      IN      NS      b.root-servers.net.
  .                       30      IN      NS      c.root-servers.net.
  .                       30      IN      NS      d.root-servers.net.
  .                       30      IN      NS      e.root-servers.net.
  .                       30      IN      NS      f.root-servers.net.
  .                       30      IN      NS      g.root-servers.net.

  ;; Query time: 1 msec
  ;; SERVER: 10.96.0.10#53(10.96.0.10) (UDP)
  ;; WHEN: Thu May 28 06:11:30 UTC 2026
  ;; MSG SIZE  rcvd: 443


.. note::

  `dig` (Domain Information Groper) is a command-line tool used to query DNS servers and troubleshoot DNS-related issues such as hostname 
  resolution, IP lookups, and reverse DNS queries.


.. code-block:: bash

  cat /etc/resolv.conf

  search default.svc.cluster.local svc.cluster.local cluster.local ec2.internal
  nameserver 10.96.0.10
  options ndots:5

.. code-block:: bash


  dig @10.96.0.10 -x 10.96.0.10

  ; <<>> DiG 9.20.18-1ubuntu2.1-Ubuntu <<>> @10.96.0.10 -x 10.96.0.10
  ; (1 server found)
  ;; global options: +cmd
  ;; Got answer:
  ;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 63893
  ;; flags: qr aa rd; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1
  ;; WARNING: recursion requested but not available

  ;; OPT PSEUDOSECTION:
  ; EDNS: version: 0, flags:; udp: 1232
  ; COOKIE: 62a9aaa055e92ae1 (echoed)
  ;; QUESTION SECTION:
  ;10.0.96.10.in-addr.arpa.       IN      PTR

  ;; ANSWER SECTION:
  10.0.96.10.in-addr.arpa. 30     IN      PTR     kube-dns.kube-system.svc.cluster.local.

  ;; Query time: 1 msec
  ;; SERVER: 10.96.0.10#53(10.96.0.10) (UDP)
  ;; WHEN: Thu May 28 06:16:52 UTC 2026
  ;; MSG SIZE  rcvd: 139


.. note::


  The command `dig @10.96.0.10 -x 10.96.0.10` uses the `dig` utility to perform a reverse DNS lookup by querying the DNS server at `10.96.0.10`,
  which is commonly the CoreDNS service in a Kubernetes cluster. The `-x` option tells `dig` to resolve an IP address back to a hostname rather 
  than resolving a hostname to an IP address. In other words, the command asks the question: 
  
  “What hostname is associated with the IP address 10.96.0.10?” 
  
  This is useful for testing Kubernetes DNS functionality and troubleshooting service discovery.



Now let us access the service from the container.

.. code-block:: bash

  curl service-lab.accounting.svc.cluster.local.

  <!DOCTYPE html>
  <html>
  <head>
  <title>Welcome to nginx!</title>
  <style>
      body {
          width: 35em;
          margin: 0 auto;
          font-family: Tahoma, Verdana, Arial, sans-serif;
      }
  </style>
  </head>
  <body>
  <h1>Welcome to nginx!</h1>
  <p>If you see this page, the nginx web server is successfully installed and
  working. Further configuration is required.</p>

  <p>For online documentation and support please refer to
  <a href="http://nginx.org/">nginx.org</a>.<br/>
  Commercial support is available at
  <a href="http://nginx.com/">nginx.com</a>.</p>

  <p><em>Thank you for using nginx.</em></p>
  </body>
  </html>




.. code-block:: bash

  curl service-lab

  curl: (6) Could not resolve host: service-lab


.. code-block:: bash


  curl service-lab.accounting

  <!DOCTYPE html>
  <html>
  <head>
  <title>Welcome to nginx!</title>
  <style>
      body {
          width: 35em;
          margin: 0 auto;
          font-family: Tahoma, Verdana, Arial, sans-serif;
      }
  </style>
  </head>
  <body>
  <h1>Welcome to nginx!</h1>
  <p>If you see this page, the nginx web server is successfully installed and
  working. Further configuration is required.</p>

  <p>For online documentation and support please refer to
  <a href="http://nginx.org/">nginx.org</a>.<br/>
  Commercial support is available at
  <a href="http://nginx.com/">nginx.com</a>.</p>

  <p><em>Thank you for using nginx.</em></p>
  </body>
  </html>



.. note::

  In Kubernetes, DNS resolution inside a Pod uses built-in search domains defined in `/etc/resolv.conf`, typically:

  * `accounting.svc.cluster.local`

  * `svc.cluster.local`

  * `cluster.local`


  Because of these search domains, `curl service-lab.accounting` works since it is expanded to `service-lab.accounting.svc.cluster.local`, and the 
  full FQDN `curl service-lab.accounting.svc.cluster.local` always works because it is explicitly complete. However, `curl service-lab` may fail 
  because it relies entirely on DNS search expansion and can be ambiguous without the namespace being included.



Now, exit the container

.. code-block:: bash

  exit


Now let's examine the service in details

.. code-block:: bash

  kubectl -n kube-system get svc

  NAME       TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)                  AGE
  kube-dns   ClusterIP   10.96.0.10   <none>        53/UDP,53/TCP,9153/TCP   100d


.. code-block:: bash

  kubectl -n kube-system get svc kube-dns -o yaml

  apiVersion: v1
  kind: Service
  metadata:
    annotations:
      prometheus.io/port: "9153"
      prometheus.io/scrape: "true"
    creationTimestamp: "2026-02-16T23:01:12Z"
    labels:
      k8s-app: kube-dns
      kubernetes.io/cluster-service: "true"
      kubernetes.io/name: CoreDNS
    name: kube-dns
    namespace: kube-system
    resourceVersion: "234"
    uid: fd84c0d3-586f-4cfd-8c47-a5c293f11531
  spec:
    clusterIP: 10.96.0.10
    clusterIPs:
    - 10.96.0.10
    internalTrafficPolicy: Cluster
    ipFamilies:
    - IPv4
    ipFamilyPolicy: SingleStack
    ports:
    - name: dns
      port: 53
      protocol: UDP
      targetPort: 53
    - name: dns-tcp
      port: 53
      protocol: TCP
      targetPort: 53
    - name: metrics
      port: 9153
      protocol: TCP
      targetPort: 9153
    selector:
      k8s-app: kube-dns
    sessionAffinity: None
    type: ClusterIP
  status:
    loadBalancer: {}

.. code-block:: bash

  kubectl get pod -l k8s-app --all-namespaces

  NAMESPACE     NAME                                       READY   STATUS    RESTARTS   AGE
  kube-system   calico-kube-controllers-6fd9cc49d6-sgldb   1/1     Running   0          27d
  kube-system   calico-node-658ph                          1/1     Running   0          100d
  kube-system   calico-node-fqxdm                          1/1     Running   0          100d
  kube-system   calico-node-t75zw                          1/1     Running   0          100d
  kube-system   coredns-7d764666f9-7ldnb                   1/1     Running   0          27d
  kube-system   coredns-7d764666f9-v86v6                   1/1     Running   0          27d
  kube-system   kube-proxy-6c56j                           1/1     Running   0          27d
  kube-system   kube-proxy-8n858                           1/1     Running   0          27d
  kube-system   kube-proxy-c2vrs                           1/1     Running   0          27d


.. code-block:: bash

  kubectl -n kube-system get pod coredns-7d764666f9-7ldnb -o yaml


.. code-block:: bash

  kubectl -n kube-system get configmaps

  NAME                                                   DATA   AGE
  calico-config                                          4      100d
  coredns                                                1      100d
  extension-apiserver-authentication                     6      100d
  kube-apiserver-legacy-service-account-token-tracking   1      100d
  kube-proxy                                             2      100d
  kube-root-ca.crt                                       1      100d
  kubeadm-config                                         1      100d
  kubelet-config                                         1      100d


.. code-block:: bash

  kubectl -n kube-system get configmaps coredns -o yaml

  apiVersion: v1
  data:
    Corefile: |
      .:53 {
          errors
          health {
             lameduck 5s
          }
          ready
          kubernetes cluster.local in-addr.arpa ip6.arpa {
             pods insecure
             fallthrough in-addr.arpa ip6.arpa
             ttl 30
          }
          prometheus :9153
          forward . /etc/resolv.conf {
             max_concurrent 1000
          }
          cache 30 {
             disable success cluster.local
             disable denial cluster.local
          }
          loop
          reload
          loadbalance
      }
  kind: ConfigMap
  metadata:
    creationTimestamp: "2026-02-16T23:01:12Z"
    name: coredns
    namespace: kube-system
    resourceVersion: "224"
    uid: 982b693f-8dfd-4a14-8689-89ac8e38597f


.. note::

  This CoreDNS ConfigMap defines how DNS resolution works inside the Kubernetes cluster. It listens 
  on port 53 and uses the `kubernetes` plugin to resolve internal service and pod names under the 
  `cluster.local` domain, including reverse DNS zones (`in-addr.arpa` and `ip6.arpa`), 
  enabling service discovery within the cluster. Queries that are not part of the cluster 
  domain are forwarded to upstream DNS servers via `/etc/resolv.conf`, allowing external 
  domain resolution. It includes health and readiness checks for Kubernetes, Prometheus 
  metrics on port 9153 for monitoring, and features like query caching (30s, with caching 
  disabled for `cluster.local` to keep service discovery fresh), loop detection, configuration 
  reloads, and load balancing of DNS responses across service endpoints.

Now that we can see everything is running, let's make some changes to the objects related to CoreDNS 



.. code-block:: bash

    kubectl -n kube-system get configmaps coredns -o yaml > coredns-backup.yaml


Add a rewrite statement such that `test.io` will redirect to `cluster.local`.

.. code-block:: yaml

  apiVersion: v1
  data:
    Corefile: |
      .:53 {
          rewrite name regex (.*)\.test\.io {1}.default.svc.cluster.local
          errors
          health {
             lameduck 5s
          }



We will now delete the coredns pods causing them to re-read the updated configmap.

.. code-block:: bash

  kubectl get pod -l k8s-app --all-namespaces

  NAMESPACE     NAME                                       READY   STATUS    RESTARTS   AGE
  kube-system   calico-kube-controllers-6fd9cc49d6-sgldb   1/1     Running   0          27d
  kube-system   calico-node-658ph                          1/1     Running   0          100d
  kube-system   calico-node-fqxdm                          1/1     Running   0          100d
  kube-system   calico-node-t75zw                          1/1     Running   0          100d
  kube-system   coredns-7d764666f9-7ldnb                   1/1     Running   0          27d
  kube-system   coredns-7d764666f9-v86v6                   1/1     Running   0          27d
  kube-system   kube-proxy-6c56j                           1/1     Running   0          27d
  kube-system   kube-proxy-8n858                           1/1     Running   0          27d
  kube-system   kube-proxy-c2vrs                           1/1     Running   0          27d

.. code-block:: bash

  kubectl -n kube-system delete pod coredns-7d764666f9-7ldnb coredns-7d764666f9-v86v6 

  pod "coredns-7d764666f9-7ldnb" deleted from kube-system namespace
  pod "coredns-7d764666f9-v86v6" deleted from kube-system namespace

Now we will create a new web server and create a ClusterIP service to verify the address works. 
Note the new service IP to start with a reverse lookup.

.. code-block:: bash

  kubectl create deployment nginx --image=nginx

  kubectl expose deployment nginx --type=ClusterIP --port=80

.. code-block:: bash

  kubectl get svc

  NAME         TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)   AGE
  kubernetes   ClusterIP   10.96.0.1        <none>        443/TCP   100d
  nginx        ClusterIP   10.108.208.182   <none>        80/TCP    18s

We will now log into the ubuntu container and test the URL rewrite starting with the reverse 
IP resolution.

.. code-block:: bash

  kubectl exec -it ubuntu -- /bin/bash


.. code-block:: bash

  dig -x 10.108.208.182

  ; <<>> DiG 9.20.18-1ubuntu2.1-Ubuntu <<>> -x 10.108.208.182
  ;; global options: +cmd
  ;; Got answer:
  ;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 49837
  ;; flags: qr aa rd; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1
  ;; WARNING: recursion requested but not available

  ;; OPT PSEUDOSECTION:
  ; EDNS: version: 0, flags:; udp: 1232
  ; COOKIE: d788b6c2a8f3e736 (echoed)
  ;; QUESTION SECTION:
  ;182.208.108.10.in-addr.arpa.   IN      PTR

  ;; ANSWER SECTION:
  182.208.108.10.in-addr.arpa. 30 IN      PTR     nginx.default.svc.cluster.local.

  ;; Query time: 0 msec
  ;; SERVER: 10.96.0.10#53(10.96.0.10) (UDP)
  ;; WHEN: Thu May 28 10:06:42 UTC 2026
  ;; MSG SIZE  rcvd: 140


.. code-block:: bash

  dig nginx.default.svc.cluster.local.

  ; <<>> DiG 9.20.18-1ubuntu2.1-Ubuntu <<>> nginx.default.svc.cluster.local.
  ;; global options: +cmd
  ;; Got answer:
  ;; WARNING: .local is reserved for Multicast DNS
  ;; You are currently testing what happens when an mDNS query is leaked to DNS
  ;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 52776
  ;; flags: qr aa rd; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1
  ;; WARNING: recursion requested but not available

  ;; OPT PSEUDOSECTION:
  ; EDNS: version: 0, flags:; udp: 1232
  ; COOKIE: 77f5c10cc70d24c3 (echoed)
  ;; QUESTION SECTION:
  ;nginx.default.svc.cluster.local. IN    A

  ;; ANSWER SECTION:
  nginx.default.svc.cluster.local. 30 IN  A       10.108.208.182

  ;; Query time: 0 msec
  ;; SERVER: 10.96.0.10#53(10.96.0.10) (UDP)
  ;; WHEN: Thu May 28 10:07:29 UTC 2026
  ;; MSG SIZE  rcvd: 119


.. code-block:: bash

  dig nginx.test.io

  ; <<>> DiG 9.20.18-1ubuntu2.1-Ubuntu <<>> nginx.test.io
  ;; global options: +cmd
  ;; Got answer:
  ;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 48550
  ;; flags: qr aa rd; QUERY: 1, ANSWER: 1, AUTHORITY: 0, ADDITIONAL: 1
  ;; WARNING: recursion requested but not available

  ;; OPT PSEUDOSECTION:
  ; EDNS: version: 0, flags:; udp: 1232
  ; COOKIE: 8a7222aaf1f92b39 (echoed)
  ;; QUESTION SECTION:
  ;nginx.test.io.                 IN      A

  ;; ANSWER SECTION:
  nginx.default.svc.cluster.local. 30 IN  A       10.108.208.182

  ;; Query time: 1 msec
  ;; SERVER: 10.96.0.10#53(10.96.0.10) (UDP)
  ;; WHEN: Thu May 28 10:08:19 UTC 2026
  ;; MSG SIZE  rcvd: 101




.. code-block:: bash

  exit