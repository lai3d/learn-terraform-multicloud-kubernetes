# Copyright (c) HashiCorp, Inc.
# SPDX-License-Identifier: MPL-2.0

provider "aws" {
  region = "us-east-2"
}

data "aws_availability_zones" "available" {}

locals {
  cluster_name = "education-eks-${random_string.suffix.result}"
}

resource "random_string" "suffix" {
  length  = 8
  special = false
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  name                 = "education-eks"
  cidr                 = "10.0.0.0/16"
  azs                  = data.aws_availability_zones.available.names
  private_subnets      = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets       = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
  }

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = "1"
  }
}

module "eks" {
  source          = "terraform-aws-modules/eks/aws"
  cluster_name    = local.cluster_name
  cluster_version = "1.27"

  cluster_endpoint_public_access  = true

  # subnets         = module.vpc.private_subnets
  // https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest
  # subnet_ids      = ["subnet-abcde012", "subnet-bcde012a", "subnet-fghi345a"]
  subnet_ids      = module.vpc.private_subnets
  vpc_id          = module.vpc.vpc_id
  version         = "19.15.3"

  # workers_group_defaults = {
  #   root_volume_type = "gp2"
  # }

  # worker_groups = [
  #   {
  #     name                 = "${local.cluster_name}_worker_group"
  #     instance_type        = "t2.small"
  #     asg_desired_capacity = 3
  #   }
  # ]

  # EKS Managed Node Group(s)
  eks_managed_node_group_defaults = {
    instance_types = ["m6i.large", "m5.large", "m5n.large", "m5zn.large"]
  }

  eks_managed_node_groups = {
    blue = {}
    green = {
      min_size     = 1
      max_size     = 10
      desired_size = 3

      instance_types = ["m5.large"]
    }
  }
}
