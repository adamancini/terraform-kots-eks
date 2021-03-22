resource "aws_s3_bucket_object" "script" {
  count  = var.create_admin_console_script ? 1 : 0
  bucket = module.dbt_cloud_app_bucket.this_s3_bucket_id
  key    = "terraform/config_script.sh"
  source = local_file.script.0.filename
}

resource "aws_s3_bucket_object" "config" {
  count  = var.create_admin_console_script ? 1 : 0
  bucket = module.dbt_cloud_app_bucket.this_s3_bucket_id
  key    = "terraform/config.yaml"
  source = local_file.config.0.filename
}

resource "local_file" "script" {
  count    = var.create_admin_console_script ? 1 : 0
  filename = "./dbt_config.sh"
  content  = <<EOT
aws configure --profile ${var.appslug}-${var.namespace}-${var.environment} set aws_access_key_id ${var.aws_access_key_id}
aws configure --profile ${var.appslug}-${var.namespace}-${var.environment} set aws_secret_access_key ${var.aws_secret_access_key}
aws configure --profile ${var.appslug}-${var.namespace}-${var.environment} set region ${var.region}
aws eks update-kubeconfig --profile ${var.appslug}-${var.namespace}-${var.environment} --name ${var.create_eks_cluster ? module.eks.0.cluster_id : var.cluster_name} --role-arn ${var.creation_role_arn}
kubectl config set-context --current --namespace=${var.existing_namespace ? var.custom_namespace : kubernetes_namespace.dbt_cloud.0.metadata.0.name}
curl https://kots.io/install | bash
kubectl kots install ${var.appslug}${var.release_channel} --namespace ${var.existing_namespace ? var.custom_namespace : kubernetes_namespace.dbt_cloud.0.metadata.0.name} --shared-password ${var.admin_console_password} --config-values ${local_file.config.0.filename}
EOT
}

resource "local_file" "config" {
  count    = var.create_admin_console_script ? 1 : 0
  filename = "./config.yaml"
  content  = <<EOT
apiVersion: kots.io/v1beta1
kind: ConfigValues
metadata:
  creationTimestamp: null
  name: ${var.appslug}
spec:
  values:
    app_memory:
      value: ${var.app_memory}
    app_replicas:
      value: "${var.app_replicas}"
    artifacts_s3_bucket:
      value: ${local.s3_bucket_names.1}
    aws_access_key_id:
      value: ${var.aws_access_key_id}
    aws_secret_access_key:
      value: ${var.aws_secret_access_key}
    hostname:
      value: ${var.hostname_affix == "" ? var.environment : var.hostname_affix}.${var.hosted_zone_name}
    ide_storage_class:
      value: ${var.ide_storage_class}
    imageRegistry:
      value: registry.replicated.com/dbt-cloud-v1/
    kms_key_id:
      value: ${module.kms_key.key_arn}
    nginx_memory:
      value: ${var.nginx_memory}
    s3_endpoint_url:
      value: https://s3.${var.region}.amazonaws.com
    s3_region:
      value: ${var.region}
    storage_method:
      default: s3
status: {}
EOT
}
