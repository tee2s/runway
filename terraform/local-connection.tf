resource "local_file" "runtime_ssh_config" {
  count = var.runtime_enabled ? 1 : 0

  filename = pathexpand("~/.ssh/config.d/${var.project_name}")

  content = <<-EOT
  Host ${var.project_name}
      HostName ${local.runtime_public_ip}
      User ubuntu
      IdentityFile ${var.runtime_private_key_path}
      IdentitiesOnly yes
  EOT
}

resource "local_file" "runtime_dcv_connection_file" {
  count = var.runtime_enabled ? 1 : 0

  filename = pathexpand("~/.config/dcv/${var.project_name}.dcv")

  content = <<-EOT
  [version]
  format=1.0

  [connect]
  host=${local.runtime_public_ip}
  port=8443
  sessionid=console
  user=ubuntu
  proxytype=DIRECT
  transport=auto
  certificatevalidationpolicy=accept-untrusted
  EOT
}
