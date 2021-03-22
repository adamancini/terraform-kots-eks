output "instance_url" {
  value       = "${var.hostname_affix == "" ? var.environment : var.hostname_affix}.${var.hosted_zone_name}"
  description = "The URL where the dbt Cloud instance can be accessed."
}

output "kms_key_arn" {
  value       = module.kms_key.key_arn
  description = "The ARN of the KMS key created. May be manually entered for encryption in the configuration console if not using the generated script."
}
