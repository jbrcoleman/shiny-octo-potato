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

## 2. Configure Karpenter Resources

Provision the Karpenter `EC2NodeClass` and `NodePool` resources:

```bash
kubectl apply --server-side -f kubernetes/deployment.yaml
```

## 3. Deploy Example Application

Deploy the example deployment (initial replicas set to 0):

```bash
kubectl apply --server-side -f example.yaml
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

# Cleanup

First, scale down the deployment to de-provision Karpenter resources:

```bash
kubectl delete -f example.yaml
```

Remove the Karpenter Helm chart:

```bash
terraform destroy -target=helm_release.karpenter --auto-approve
```

Finally, destroy the remaining infrastructure:

```bash
terraform destroy -target="module.eks_blueprints_addons" -auto-approve
terraform destroy -target="module.eks" -auto-approve
terraform destroy -auto-approve
```
