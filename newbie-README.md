# How to use an install egress-router into a K8S cluster 

This documentation aims to allow to use egress-router as a CNI plugin, into a K8S cluster, for a "newbie" about egress routers and CNI plugins.

One the plugin is available, all your pods will be able to have a new extra interface that routes requests to a specific destination. It is useful to access external resources, that are only open to one specific source (your egress-router).

Pod --> egress-router --> firewall --> destination

The firewall is configured to only admit connections from an specific source.

So you can create the egress-router:

```
apiVersion: "k8s.cni.cncf.io/v1"
kind: NetworkAttachmentDefinition
metadata:
  name: egress-router
spec:
  config: '{
    "cniVersion": "0.4.0",
    "type": "egress-router",
    "name": "egress-router",
    "ip": {
      "addresses": [
        "192.168.123.99"
        ],
      "destinations": [
        "192.168.123.91"
      ],
      "gateway": "192.168.123.1"
      }
    }'
```

The packages to these router will be forwarded to the destination, with the source, with the ip of the egress router. This is important, the destination see the origin from the router, not from the pod.

And then, you can attach this extra interface to your pods:

```
---
apiVersion: v1
kind: Pod
metadata:
  name: egress-router-pod
  annotations:
    k8s.v1.cni.cncf.io/networks: egress-router
spec:
  containers:
    - name: openshift-egress-router-pod
      command: ["/bin/bash", "-c", "sleep 999999999"]
      image: centos/tools
      securityContext:
        privileged: true
``` 

The annotation egress-router points to a CNI plugin (binary) that needs to exists in all the nodes.

## 1st enable the NetworkAttachmentDefinition CRD: Multus-cni

To enable the definition of NetworkAttachmentDefinition you have to install multus:

```
$> curl https://raw.githubusercontent.com/k8snetworkplumbingwg/multus-cni/master/images/multus-daemonset.yml > multus-daemonset.yaml
$> kubectl apply -f multus-daemonset.yaml
```

and we have the CRDs:
```
# kubectl get crd
NAME                                             CREATED AT
network-attachment-definitions.k8s.cni.cncf.io   2021-06-10T17:21:18Z
```

## 2nd create the NetworkAttachmentDefintion

An example:

```
apiVersion: "k8s.cni.cncf.io/v1"
kind: NetworkAttachmentDefinition
metadata:
  name: egress-router
spec:
  config: '{
    "cniVersion": "0.4.0",
    "type": "egress-router",
    "name": "egress-router",
    "ip": {
      "addresses": [
        "192.168.99.5"  
        ],
      "destinations": [
        "185.172.149.96"
      ],
      "gateway": "192.168.99.1"
      }
    }'
```

 * Addresses: this is the ip of the router, as if it were another node in our network
 * destinations:  it is keycdn.com for testing
So we create like a router (192.168.99.5) that forwards everything to keycdn.com (first example found with curl command).

 ## 3rd create the Pod
 
Now we can create a pod with this extra Network:
 
```
apiVersion: v1
kind: Pod
metadata:
  name: egress-router-pod
  annotations:
    k8s.v1.cni.cncf.io/networks: egress-router
spec:
  containers:
    - name: openshift-egress-router-pod
      command: ["/bin/bash", "-c", "sleep 999999999"]
      image: centos/tools
      securityContext:
        privileged: true
```

But, this will use Multus CNI that will call the egress-router-cni plugin, as it was pointed in the router configuration. You need the egress-router-cni binary installed.

You will see these errors in your pod:

```
03b06d5d32ce565a4b24dab0f8469c876755267da969834d37" network for pod "egress-router-pod-2": networkPlugin cni failed to set up pod "egress-router-pod-2_default" network: [default/egress-router-pod-2:egress-router]: error adding container to network "egress-router": failed to find plugin "egress-router" in path [/opt/cni/bin /opt/cni/bin], failed to clean up sandbox container "f9a3216b5d7a9d03b06d5d32ce565a4b24dab0f8469c876755267da969834d37" network for pod "egress-router-pod-2": networkPlugin cni failed to teardown pod "egress-router-pod-2_default" network: delegateDel: error invoking DelegateDel - "egress-router": error in getting result from DelNetwork: failed to find plugin "egress-router" in path [/opt/cni/bin /opt/cni/bin]]

```

In this tutorial I will compile the binary, directly in the only cluster node I am using. In a more real environment, you can use an egress-router image to copy locally the binary in every host (daemonset)

Lets clone the repo, and compile (golang previously installed):

```
# git clone https://github.com/jgato/egress-router-cni
# cd egress-router-cni
# ./hack/build-go.sh 
# cp bin/egress-router /opt/cni/bin/
``` 

Now the plugin is found, but I have hundreds of lines like this:

```
  Normal   AddedInterface          8s                  multus             Add eth0 [10.244.0.79/24] from cbr0
  Normal   AddedInterface          7s                  multus             Add eth0 [10.244.0.80/24] from cbr0
  Normal   AddedInterface          6s                  multus             Add eth0 [10.244.0.81/24] from cbr0
  Normal   AddedInterface          5s                  multus             Add eth0 [10.244.0.82/24] from cbr0
  Normal   AddedInterface          4s                  multus             Add eth0 [10.244.0.83/24] from cbr0
  Normal   AddedInterface          3s                  multus             Add eth0 [10.244.0.84/24] from cbr0
  Normal   AddedInterface          2s                  multus             Add eth0 [10.244.0.85/24] from cbr0
  Normal   AddedInterface          1s                  multus             Add eth0 [10.244.0.86/24] from cbr0

```

Maybe because of using flannel.

