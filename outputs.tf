output "service" {
  description = "The systemd service that runs Homepage on each host."
  value       = "homepage.service"
}

output "image" {
  description = "The Homepage image the hosts run."
  value       = local.image
}

output "url" {
  description = "Where Homepage answers on each host itself, such as \"http://127.0.0.1:3000\". Point a reverse proxy here, and add its host name to allowed_hosts."
  value       = local.local_url
}

output "config_dir" {
  description = "Directory on each host holding Homepage's config files."
  value       = local.config
}
