
deployment.kubernetes.io/revision: "1"
-------------------------------------

The current generation of the Deployment is 1, which means this is the first rollout of the Deployment. \
Each time you update the Deployment, this revision number will increment.


progressDeadlineSeconds : 600
-----------------------------

Kubernetes gives the Deployment 600 seconds (10 minutes) to make rollout progress before marking the rollout as failed/stalled.


During a Deployment update, Kubernetes expects forward movement such as:

    * new Pods being created

    * new Pods becoming Ready

    * old Pods being replaced

    * available replica count increasing

    * ReplicaSet scaling advancing

If none of that happens for the deadline period, Kubernetes considers the rollout stuck.


RollingUpdateStrategy
---------------------

RollingUpdateStrategy defines how Kubernetes replaces old Pods with new Pods during a Deployment update, so your application can keep running 
while changes are rolled out.

When somethingn is changed in the Deployment spec, Kubernetes creates a new ReplicaSet with the updated Pod template. 
Then it gradually scales up the new ReplicaSet while scaling down the old ReplicaSet, following the rules defined in RollingUpdateStrategy.
It does not normally kill everything at once.

1. **maxUnavailable**: How many desired Pods are allowed to be unavailable during the update. In this example, up to 25% of the desired Pods can be 
unavailable at any time during the update.

2. **maxSurge**: How many extra Pods can be created above the desired number of Pods during the update. In this example, up to 25% more Pods than 
the desired count can be created temporarily during the update.


imagePullPolicy: Always
------------------------

This means that every time a Pod is created, Kubernetes will always pull the container image from the registry, even if it already exists on the node. 
This ensures that the latest version of the image is used.

terminationMessage
------------------

When a container in a Pod terminates, Kubernetes captures the termination message, which can contain details about why the container stopped.

1. **terminationMessagePath**: This is the file path inside the container where the termination message is written. By default, it is /dev/termination-log.

2. **terminationMessagePolicy**: This defines how Kubernetes retrieves the termination message. The default policy is "File", which means Kubernetes reads 
the message from the specified file path.