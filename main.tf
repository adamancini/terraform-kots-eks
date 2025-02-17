resource "aws_security_group" "internal" {
  count       = var.custom_internal_security_group_id == "" ? 1 : 0
  name        = "internal"
  description = "Allow all internal traffic"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["${var.cidr_block}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    ignore_changes = [ingress]
  }

  tags = map(
    "Name", "internal",
    "Stack", "${var.namespace}-${var.environment}",
    "Customer", var.namespace
  )
}

resource "kubernetes_namespace" "dbt_cloud" {
  count = var.existing_namespace ? 0 : 1
  metadata {
    name = var.custom_namespace == "" ? "dbt-cloud-${var.namespace}-${var.environment}" : var.custom_namespace
  }
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
  load_config_file       = false
  version                = "~> 1.9"
}

module "eks" {
  count   = var.create_eks_cluster ? 1 : 0
  source  = "terraform-aws-modules/eks/aws"
  version = "12.2.0"

  create_eks = true

  cluster_version = "1.16"
  cluster_name    = "${var.namespace}-${var.environment}"
  vpc_id          = var.vpc_id
  subnets         = var.private_subnets

  worker_groups_launch_template = [
    {
      name = "primary-worker-group-1-16-${var.k8s_node_size}"

      # override ami_id for this launch template
      ami_id = data.aws_ami.eks_worker_ami_1_16.0.id

      instance_type        = var.k8s_node_size
      asg_desired_capacity = var.k8s_node_count
      asg_min_size         = var.k8s_node_count
      asg_max_size         = var.k8s_node_count

      suspended_processes = ["AZRebalance"]

      key_name                      = "${var.namespace}-${var.environment}"
      additional_security_group_ids = [var.custom_internal_security_group_id == "" ? aws_security_group.internal.0.id : var.custom_internal_security_group_id]
      kubelet_extra_args            = local.kubelet_extra_args
      pre_userdata                  = "${local.bionic_1_16_node_userdata}${var.additional_k8s_user_data}"

      enabled_metrics = [
        "GroupStandbyInstances",
        "GroupTotalInstances",
        "GroupPendingInstances",
        "GroupTerminatingInstances",
        "GroupDesiredCapacity",
        "GroupInServiceInstances",
        "GroupMinSize",
        "GroupMaxSize",
      ]
    },
  ]

  workers_role_name           = "${var.namespace}-${var.environment}-workers-role"
  workers_additional_policies = local.aws_worker_policy_arns

  cluster_log_retention_in_days = 0
  cluster_enabled_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler",
  ]

  cluster_endpoint_private_access = true

  manage_aws_auth = true
  map_roles = [
    {
      rolearn  = "arn:aws:iam::850607893674:role/${var.namespace}-${var.environment}-workers-role"
      username = "system:node:{{EC2PrivateDNSName}}"
      groups   = ["system:masters", "system:bootstrappers"]
    },
  ]

  write_kubeconfig = false

  tags = map(
    "Name", "eks",
    "Stack", "${var.namespace}-${var.environment}",
    "Customer", var.namespace
  )
}
