Security
============

Create two namespaces, one for production and the other for development:

.. code-block:: bash

    kubectl create ns production

    namespace/development created

.. code-block:: bash

    kubectl create ns development

    namespace/production created


A Kubernetes **context** is a named configuration in the kubeconfig file that combines a **cluster**, 
a **user (credentials)**, and an optional **default namespace** into a single profile. It 
tells `kubectl` which Kubernetes cluster to connect to, how to authenticate, and which namespace 
to use by default when running commands. Contexts make it easy to switch between environments 
such as development, staging, and production without manually specifying connection details each time. 
You can view available contexts with `kubectl config get-contexts`, check the active one with 
`kubectl config current-context`, and switch between them using 
`kubectl config use-context <context-name>`.


.. code-block:: bash

    kubectl config get-contexts

    CURRENT   NAME                          CLUSTER      AUTHINFO           NAMESPACE
    *         kubernetes-admin@kubernetes   kubernetes   kubernetes-admin 


Create a new user:

.. code-block:: bash

    sudo useradd -s /bin/bash DevDan
    sudo passwd DevDan


Let's use the password `lftr@in`.


Now let's create an RSA key for the user

.. code-block:: bash

    openssl genrsa -out DevDan.key 2048

.. note::

    This command generates a 2048-bit RSA private key and saves it to a file named `DevDan.key`. 
    The private key is used for authentication and should be kept secure. You can use this key 
    to create a certificate signing request (CSR) or to authenticate directly with the Kubernetes 
    API server, depending on your setup.

.. code-block:: bash

    openssl req -new -key DevDan.key -out DevDan.csr -subj "/CN=DevDan/O=development"

    Certificate request self-signature ok
    subject=CN = DevDan, O = development


.. note::

    This command creates a **Certificate Signing Request (CSR)** named `DevDan.csr` using the private 
    key stored in `DevDan.key`. The CSR contains the identity information that will be included in 
    the certificate, with `CN=DevDan` specifying the Common Name and `O=development` specifying the 
    Organization. The generated CSR can then be submitted to a Certificate Authority (CA) or used 
    with a Kubernetes CA to issue a signed certificate.

.. code-block:: bash

    sudo openssl x509 -req -in DevDan.csr \
      -CA /etc/kubernetes/pki/ca.crt \
      -CAkey /etc/kubernetes/pki/ca.key \
      -CAcreateserial \
      -out DevDan.crt -days 45

.. note::

    This command signs the Certificate Signing Request (`DevDan.csr`) using the Kubernetes Certificate 
    Authority (CA) certificate and private key, generating a signed client certificate named 
    `DevDan.crt`. The certificate is valid for **45 days**, and the `-CAcreateserial` option creates 
    a serial number file for tracking issued certificates. This signed certificate can then be used 
    for authentication with the Kubernetes cluster.


.. note::

    The certificate and signing process provides a **trusted identity** for a user in Kubernetes. 
    The private key proves that the user owns the identity, while the signed certificate confirms 
    that the identity has been verified by a trusted Certificate Authority (CA), such as the cluster's 
    CA. When a user connects to the Kubernetes API server, the certificate is presented for 
    authentication, and the API server verifies that it was signed by a trusted CA before allowing 
    access. Without a valid signed certificate, Kubernetes cannot authenticate the user, and access 
    to the cluster is denied.


.. code-block:: bash

    kubectl config set-credentials DevDan \
        --client-certificate=/home/ubuntu/DevDan.crt \
        --client-key=/home/ubuntu/DevDan.key

    User "DevDan" set.



.. note::

    This command creates or updates a user entry named **DevDan** in the kubeconfig file and 
    associates it with the specified client certificate and private key. When `kubectl` connects 
    to the Kubernetes API server, it uses these credentials to authenticate as the user identified 
    by the certificate.

.. code-block:: bash

    grep DevDan .kube/config

    - name: DevDan
        client-certificate: /home/ubuntu/DevDan.crt
        client-key: /home/ubuntu/DevDan.key


.. code-block:: bash

    kubectl config set-context DevDan-context \
      --cluster=kubernetes \
      --namespace=development \
      --user=DevDan

    Context "DevDan-context" created.


This command creates a **Kubernetes context** named `DevDan-context` that links together the 
**kubernetes cluster**, the **DevDan user credentials**, and sets the default namespace to 
**development**. It allows you to easily switch to this combined configuration so that all `kubectl` 
commands automatically use the specified cluster, user, and namespace.

We can see that the context is properly configured:

.. code-block:: bash


    kubectl config get-contexts

    CURRENT   NAME                          CLUSTER      AUTHINFO           NAMESPACE
              DevDan-context                kubernetes   DevDan             development
    *         kubernetes-admin@kubernetes   kubernetes   kubernetes-admin


.. code-block:: yaml

    apiVersion: rbac.authorization.k8s.io/v1
    kind: Role
    metadata:
      name: developer
      namespace: development

    rules:
    - apiGroups: ["", "extensions", "apps"]
      resources: ["deployments", "replicasets", "pods"]
      verbs: ["list", "get", "watch", "create", "update", "patch", "delete"]

This YAML (`role-dev.yaml`) defines a Kubernetes **Role** named `developer` in the `development` namespace using the RBAC API (`rbac.authorization.k8s.io/v1`). 
A Role specifies **what actions are allowed on which resources within a namespace**, but it does not assign those permissions to any user—that requires 
a **RoleBinding**. 

.. note::

    RoleBinding is a Kubernetes resource that grants permissions defined in a Role to a user, group, or service account within a specific namespace. 
    It references the Role and the subjects (users, groups, or service accounts) that should receive the permissions. By creating a RoleBinding, 
    you can control who has access to perform certain actions on resources in that namespace based on the rules defined in the Role.


The `apiGroups` field identifies the Kubernetes API groups that contain the resources being controlled: `""` refers to the core API group 
(for resources such as pods), while `apps` and `extensions` contain resources such as deployments and replicasets. The `resources` field lists 
the object types the Role applies to (`pods`, `deployments`, and `replicasets`). The `verbs` field defines the permitted operations on those 
resources: `get` (read a specific object), `list` (view collections of objects), `watch` (monitor changes), `create` (create new objects), 
`update` (replace existing objects), `patch` (modify part of an object), and `delete` (remove objects). When this Role is bound to a user, 
group, or service account through a RoleBinding, it allows management of these resources within the `development` namespace only.

.. code-block:: bash

    kubectl create -f role-dev.yaml 

    role.rbac.authorization.k8s.io/developer created

Now we can create a RoleBinding to assign the `developer` Role to the `DevDan` user, `rolebind.yaml`:

.. code-block:: yaml

    apiVersion: rbac.authorization.k8s.io/v1
    kind: RoleBinding
    metadata:
      name: developer-role-binding
      namespace: development

    subjects:
      - kind: User
        name: DevDan
        apiGroup: rbac.authorization.k8s.io

    roleRef:
      kind: Role
      name: developer
      apiGroup: rbac.authorization.k8s.io



.. code-block:: bash

    kubectl create -f rolebind.yaml 

    rolebinding.rbac.authorization.k8s.io/developer-role-binding created


.. code-block:: bash

    kubectl --context=DevDan-context get pods

    No resources found in development namespace.


.. code-block:: bash

    ubuntu@ip-172-31-17-15:~$ kubectl --context=DevDan-context create deployment nginx --image=nginx
    deployment.apps/nginx created


.. code-block:: bash

    kubectl --context=DevDan-context get pods

    NAME                     READY   STATUS    RESTARTS   AGE
    nginx-56c45fd5ff-5lnmp   1/1     Running   0          10s



.. code-block:: bash

    kubectl --context=DevDan-context delete deploy nginx

    deployment.apps "nginx" deleted from development namespace

Similarly we can create multiple roles and bind them to the same or different users, allowing for fine-grained access control across various 
namespaces and resources in the Kubernetes cluster. This RBAC setup ensures that users have only the permissions they need to perform their tasks, 
enhancing the security of the cluster.

.. code-block:: bash

    kubectl -n development describe role developer

    Name:         developer
    Labels:       <none>
    Annotations:  <none>
    PolicyRule:
      Resources               Non-Resource URLs  Resource Names  Verbs
      ---------               -----------------  --------------  -----
      deployments             []                 []              [list get watch create update patch delete]
      pods                    []                 []              [list get watch create update patch delete]
      replicasets             []                 []              [list get watch create update patch delete]
      deployments.apps        []                 []              [list get watch create update patch delete]
      pods.apps               []                 []              [list get watch create update patch delete]
      replicasets.apps        []                 []              [list get watch create update patch delete]
      deployments.extensions  []                 []              [list get watch create update patch delete]
      pods.extensions         []                 []              [list get watch create update patch delete]
      replicasets.extensions  []                 []              [list get watch create update patch delete]


Admission controls
-------------------


In Kubernetes clusters where namespaces are used by regular users
(such as developers or tenant workloads) rather than cluster administrators,
a set of admission controls is typically applied to enforce security,
resource fairness, and operational stability.

These controls complement RBAC by ensuring that even permitted actions
are safe and compliant with cluster policies.

Pod Security Admission (PSA)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Pod Security Admission is the primary security mechanism for user namespaces.

Typical namespace labels:

.. code-block:: yaml

   pod-security.kubernetes.io/enforce: restricted
   pod-security.kubernetes.io/audit: restricted
   pod-security.kubernetes.io/warn: restricted


Enforces restrictions such as:

- Preventing privileged containers
- Disallowing root users inside containers
- Blocking hostPath volumes
- Restricting hostNetwork and hostPID usage
- Preventing unsafe Linux capabilities

This forms the baseline security boundary for multi-tenant namespaces.

.. note::

    You set those values as **labels on a Kubernetes Namespace**, because they configure **Pod Security Admission (PSA)** at the namespace level.

    You can apply them either with `kubectl label` or in a Namespace YAML manifest under `metadata.labels`. The key `enforce` is the strict rule 
    that blocks non-compliant pods, while `audit` logs violations without blocking them, and `warn` shows warnings but still allows creation. 
    These settings are enforced by the API server's Pod Security Admission controller before RBAC decisions complete, meaning they act as a security 
    policy for the entire namespace rather than individual pods or roles.


ResourceQuota
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

ResourceQuota limits the total amount of compute resources
that can be consumed within a namespace.

Example:

.. code-block:: yaml

   apiVersion: v1
   kind: ResourceQuota
   metadata:
     name: compute-quota
     namespace: development
   spec:
     hard:
       pods: "20"
       requests.cpu: "4"
       requests.memory: "8Gi"
       limits.cpu: "8"
       limits.memory: "16Gi"

Prevents:

- Excessive pod creation
- Resource exhaustion of the cluster
- Noisy neighbor issues

LimitRange
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

LimitRange enforces default and maximum resource constraints
for individual containers.

Example:

.. code-block:: yaml

   apiVersion: v1
   kind: LimitRange
   metadata:
     name: default-limits
     namespace: development
   spec:
     limits:
     - type: Container
       default:
         cpu: "500m"
         memory: "512Mi"
       defaultRequest:
         cpu: "200m"
         memory: "256Mi"

Prevents:

- Containers running without resource limits
- Uncontrolled CPU or memory usage

Image Policy Admission (Kyverno)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Image policy admission controls restrict which container images
can be deployed.

Typical policies include:

- Allow only trusted registries
- Block `latest` image tags
- Prevent unsigned or unverified images

Example (Kyverno-style policy):

.. code-block:: yaml

   validate:
     pattern:
       spec:
         containers:
         - image: "myregistry.com/*"


.. note::

    keyverno is a Kubernetes-native policy engine that can enforce complex policies, including image restrictions. The above example is a 
    simplified pattern that allows only images from `myregistry.com`. In practice, you would define this as a Kyverno policy resource that 
    validates pod specifications before they are admitted to the cluster, ensuring that only compliant images are used in deployments.

Non-Root Enforcement
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Security policies enforce that containers do not run as root.

Common restrictions:

- Disallow `runAsUser: 0`
- Prevent privilege escalation
- Enforce read-only root filesystem (optional)

This is often implemented via Pod Security Admission or policy engines
such as Kyverno or OPA Gatekeeper.


.. note::

    You don't directly set “disallow `runAsUser: 0`” in Roles or normal Kubernetes objects. It is enforced through **admission control policies**. 
    The simplest way is using **Pod Security Admission (PSA)** by labeling a namespace with `restricted`, which automatically blocks root containers 
    (`runAsUser: 0`) and other unsafe settings. For more explicit or custom rules, tools like **Kyverno** or **OPA Gatekeeper** are used to define 
    policies that reject root user pods. In short, this restriction is not configured in RBAC, but enforced at the **admission control layer**.


NetworkPolicy
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

NetworkPolicy provides network-level isolation between workloads.

Example default deny policy:

.. code-block:: yaml

   kind: NetworkPolicy
   apiVersion: networking.k8s.io/v1
   metadata:
     name: deny-all
     namespace: development
   spec:
     podSelector: {}
     policyTypes:
     - Ingress
     - Egress

This ensures:

- Pods cannot communicate freely by default
- Traffic must be explicitly allowed

API Priority and Fairness (APF)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

API Priority and Fairness protects the Kubernetes API server
from overload or abuse.

It ensures:

- Fair request distribution between users
- Prevention of API flooding
- Protection of control plane stability

Typical Admission Control Stack for User Namespaces
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

A standard secure namespace setup includes:

- Pod Security Admission (restricted)
- ResourceQuota (resource limits)
- LimitRange (default container limits)
- NetworkPolicy (default deny rules)
- Image policy enforcement (OPA or Kyverno)
- API Priority and Fairness (cluster-wide control)



.. note::

    Admission controls ensure that even when RBAC allows an action,
    the request must still satisfy security, resource, and policy constraints.

    A useful mental model:

    - RBAC: "Are you allowed to request this?"
    - Admission Control: "Is this request safe and compliant?"
    - Resource Policies: "How much can you consume?"
    - Network Policies: "Who can you talk to?"
  

Kubernetes Authentication Best Practices
-----------------------------------------

These practices help secure access to the Kubernetes API server.

Disable Anonymous Access
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

.. code-block:: bash

    --anonymous-auth=false

This ensures all API requests must be authenticated and prevents unauthenticated access.

Use Strong Authentication
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
Prefer secure methods like:

- Client certificates (mTLS-based identity)
- OIDC (OpenID Connect via identity providers)

These methods provide verified and scalable user authentication.

Secure Token Files
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
If using bearer tokens:

- Store files securely
- Restrict permissions::

.. code-block:: bash

    chmod 600 token-file

This prevents token leakage and unauthorized cluster access.

Test Authentication
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Verify access using:

.. code-block:: bash

    kubectl --token=<token> get pods
    kubectl --user=<user> get pods

This ensures credentials and RBAC rules work correctly.

Enable Audit Logging
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

Use audit policies

.. code-block:: bash

    --audit-policy-file=/etc/kubernetes/audit-policy.yaml

Audit logs help track:

- Who accessed the cluster
- What actions were performed
- Whether access was allowed or denied



