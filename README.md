# shiny-octo-potato
This follows the steps of eks blueprint: https://aws-ia.github.io/terraform-aws-eks-blueprints/patterns/karpenter/

# Provisioning Steps

To provision the pattern, execute the following steps:

```bash
terraform init
terraform apply -target="module.vpc" -auto-approve
terraform apply -target="module.eks" -auto-approve
terraform apply -auto-approve
```

# Testing and Verification

## 1. Check Cluster Nodes

Test by listing the nodes in the cluster. You should see two Fargate nodes:

```bash
kubectl get nodes

NAME                                               STATUS   ROLES    AGE    VERSION
fargate-ip-10-0-16-92.us-west-2.compute.internal   Ready    <none>   2m3s   v1.30.0-eks-404b9c6
fargate-ip-10-0-8-95.us-west-2.compute.internal    Ready    <none>   2m3s   v1.30.0-eks-404b9c6
```

## 2. Configure Karpenter and IStIO Resources

Provision the Karpenter `EC2NodeClass` and `NodePool` resources:

```bash
kubectl apply --server-side -f kubernetes/deployment.yaml
```
Once the resources have been provisioned, you will need to replace the istio-ingress pods due to a istiod dependency issue. 
```bash
kubectl rollout restart deployment istio-ingress -n istio-ingress
```
Use the following code snippet to add the Istio Observability Add-ons on the EKS cluster with deployed Istio:
```bash
for ADDON in kiali jaeger prometheus grafana
do
    ADDON_URL="https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/$ADDON.yaml"
    kubectl apply --server-side -f $ADDON_URL
done
```

## 3. Deploy Example Application

Deploy the example deployment (initial replicas set to 0):

```bash
kubectl apply --server-side -f kubernetes/example.yaml
```

## 4. Scale the Deployment

Scale the example deployment to trigger Karpenter provisioning:

```bash
kubectl scale deployment inflate --replicas=3
```

## 5. Verify Node Provisioning

Check the nodes again to see the EC2 compute created by Karpenter:

```bash
kubectl get nodes

NAME                                               STATUS   ROLES    AGE    VERSION
fargate-ip-10-0-16-92.us-west-2.compute.internal   Ready    <none>   2m3s   v1.30.0-eks-404b9c6
fargate-ip-10-0-8-95.us-west-2.compute.internal    Ready    <none>   2m3s   v1.30.0-eks-404b9c6
ip-10-0-21-175.us-west-2.compute.internal          Ready    <none>   88s    v1.30.1-eks-e564799 # <== EC2 created by Karpenter
```
### 6. Istio
Here's the content formatted in markdown:

# Setting up the Sample Namespace with Istio

First, create the `sample` namespace and enable sidecar injection:

```bash
kubectl create namespace sample
kubectl label namespace sample istio-injection=enabled
```

Expected output:
```
namespace/sample created
namespace/sample labeled
```

### Deploy the Helloworld Application

Create and apply the helloworld configuration:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: helloworld
  labels:
    app: helloworld
    service: helloworld
spec:
  ports:
  - port: 5000
    name: http
  selector:
    app: helloworld
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: helloworld-v1
  labels:
    app: helloworld
    version: v1
spec:
  replicas: 1
  selector:
    matchLabels:
      app: helloworld
      version: v1
  template:
    metadata:
      labels:
        app: helloworld
        version: v1
    spec:
      containers:
      - name: helloworld
        image: docker.io/istio/examples-helloworld-v1
        resources:
          requests:
            cpu: "100m"
        imagePullPolicy: IfNotPresent #Always
        ports:
        - containerPort: 5000
```

Apply the configuration:
```bash
kubectl apply --server-side -f helloworld.yaml -n sample
```

Expected output:
```
service/helloworld created
deployment.apps/helloworld-v1 created
```

### Deploy the Sleep Application

Create and apply the sleep configuration:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: sleep
---
apiVersion: v1
kind: Service
metadata:
  name: sleep
  labels:
    app: sleep
    service: sleep
spec:
  ports:
  - port: 80
    name: http
  selector:
    app: sleep
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sleep
spec:
  replicas: 1
  selector:
    matchLabels:
      app: sleep
  template:
    metadata:
      labels:
        app: sleep
    spec:
      terminationGracePeriodSeconds: 0
      serviceAccountName: sleep
      containers:
      - name: sleep
        image: curlimages/curl
        command: ["/bin/sleep", "infinity"]
        imagePullPolicy: IfNotPresent
        volumeMounts:
        - mountPath: /etc/sleep/tls
          name: secret-volume
      volumes:
      - name: secret-volume
        secret:
          secretName: sleep-secret
          optional: true
```

Apply the configuration:
```bash
kubectl apply --server-side -f sleep.yaml -n sample
```

Expected output:
```
serviceaccount/sleep created
service/sleep created
deployment.apps/sleep created
```

### Verify Pod Status

Check the status of pods in the sample namespace:

```bash
kubectl get pods -n sample
```

Expected output:
```
NAME                           READY   STATUS    RESTARTS   AGE
helloworld-v1-b6c45f55-bx2xk   2/2     Running   0          50s
sleep-9454cc476-p2zxr          2/2     Running   0          15s
```

### Test the Connection

Test the connection between the sleep and helloworld applications:

```bash
kubectl exec -n sample -c sleep \
    "$(kubectl get pod -n sample -l \
    app=sleep -o jsonpath='{.items[0].metadata.name}')" \
    -- curl -v helloworld.sample:5000/hello
```

Expected output:
```
* processing: helloworld.sample:5000/hello
...
* Connection #0 to host helloworld.sample left intact
```

# Cleanup

First, scale down the deployment to de-provision Karpenter resources:

```bash
kubectl delete -f example.yaml
```

Remove the Karpenter Helm chart:

```bash
terraform destroy -target=helm_release.karpenter --auto-approve
```
Remove the Istio chart: 
```bash
terraform destroy -target='module.eks_blueprints_addons.helm_release.this["istio-ingress"]' -auto-approve
```
Finally, destroy the remaining infrastructure:

```bash
terraform destroy -target="module.eks_blueprints_addons" -auto-approve
terraform destroy -target="module.eks" -auto-approve
terraform destroy -auto-approve
```
