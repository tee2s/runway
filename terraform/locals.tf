locals {
  prefix = trimsuffix(var.parameter_prefix, "/")

  common_tags = {
    Project   = var.project_name
    ManagedBy = "terraform"
    Workload  = "robotics-sim"
  }

  s3_bucket_name = lower("${var.project_name}-${data.aws_caller_identity.current.account_id}-${var.region}")

  base_param_path = {
    bucket_name            = "${local.prefix}/bucket-name"
    base_ami_id            = "${local.prefix}/base-ami-id"
    isaac_snapshot_id      = "${local.prefix}/isaac-snapshot-id"
    project_prefix         = "${local.prefix}/config/project-prefix"
    workspace_path         = "${local.prefix}/config/workspace-path"
    isaac_webrtc_tcp_ports = "${local.prefix}/config/isaac-webrtc-tcp-ports"
    isaac_webrtc_udp_ports = "${local.prefix}/config/isaac-webrtc-udp-ports"
    dev_state_volume_id    = "${local.prefix}/dev-state-volume-id"
    dev_state_snapshot_id  = "${local.prefix}/dev-state-snapshot-id"
  }

  # Isaac Sim livestream: fixed SG + SSM documentation (TCP signaling 49100, TCP media 8210, UDP signaling 4799).
  isaac_livestream_tcp_ports_ssm = "49100,8210"
  isaac_livestream_udp_ports_ssm = "4799"

  # Trusted ingress: SSH + DCV shared by both simulation SGs; Isaac adds fixed livestream ports (same trusted_client_cidr).
  sim_ingress_admin = {
    ssh = {
      port        = 22
      protocol    = "tcp"
      description = "SSH (trusted client only)"
    }
    dcv_tcp = {
      port        = 8443
      protocol    = "tcp"
      description = "NICE DCV TCP (trusted client only)"
    }
    dcv_quic = {
      port        = 8443
      protocol    = "udp"
      description = "NICE DCV QUIC UDP (trusted client only)"
    }
  }

  isaac_ingress_livestream = {
    livestream_tcp_signaling = {
      port        = 49100
      protocol    = "tcp"
      description = "Isaac livestream TCP signaling"
    }
    livestream_tcp_media = {
      port        = 8210
      protocol    = "tcp"
      description = "Isaac livestream TCP media"
    }
    livestream_udp_signaling = {
      port        = 4799
      protocol    = "udp"
      description = "Isaac livestream UDP signaling"
    }
  }

  isaac_ingress_rules = merge(local.sim_ingress_admin, local.isaac_ingress_livestream)

  runtime_instance_types       = var.simulation_mode == "isaac" ? var.isaac_launch_template_instance_types : var.gazebo_launch_template_instance_types
  runtime_launch_template_name = var.simulation_mode == "isaac" ? aws_launch_template.isaac.name : aws_launch_template.gazebo.name
  runtime_launch_template_id   = var.simulation_mode == "isaac" ? aws_launch_template.isaac.id : aws_launch_template.gazebo.id
  runtime_security_group_id    = var.simulation_mode == "isaac" ? aws_security_group.isaac.id : aws_security_group.gazebo.id
  # When the dev-state volume is persistent, constrain the fleet to the same AZ as the volume.
  # Both this local and aws_ebs_volume.dev_state derive the AZ from aws_subnet.public["0"] independently,
  # which breaks the cycle that would otherwise form through runtime_availability_zone -> fleet.
  dev_state_persistent_az = var.persist_dev_state_volume && var.dev_state_volume_enabled ? aws_subnet.public["0"].availability_zone : null

  runtime_fleet_overrides = flatten([
    for instance_type in local.runtime_instance_types : [
      for subnet in aws_subnet.public : {
        instance_type = instance_type
        subnet_id     = subnet.id
      }
      if local.dev_state_persistent_az == null || subnet.availability_zone == local.dev_state_persistent_az
    ]
  ])
  runtime_instance_id       = try(data.aws_instance.runtime[0].id, null)
  runtime_instance_type     = try(data.aws_instance.runtime[0].instance_type, null)
  runtime_public_ip         = try(data.aws_instance.runtime[0].public_ip, null)
  runtime_availability_zone = try(data.aws_instance.runtime[0].availability_zone, null)

  ubuntu_password_hash_parameter_arn_name = trimprefix(var.ubuntu_password_hash_parameter_name, "/")
}
