locals {
  namespace = "karpenter"
}

locals {
  name            = "karpenter-blueprints"
  cluster_version = "1.30"
  region          = var.region
  node_group_name = "managed-ondemand"

#   node_iam_role_name = module.eks_blueprints_addons.karpenter.node_iam_role_name

  vpc_cidr = "10.0.0.0/16"
  # NOTE: You might need to change this less number of AZs depending on the region you're deploying to
  azs = slice(data.aws_availability_zones.available.names, 0, 3)
  istio_chart_url     = "https://istio-release.storage.googleapis.com/charts"
  istio_chart_version = "1.20.2"

  tags = {
    blueprint = local.name
  }
}