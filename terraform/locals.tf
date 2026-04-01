locals {
  prefix = trimsuffix(var.parameter_prefix, "/")

  common_tags = {
    Project  = var.project_name
    ManagedBy = "terraform"
    Workload = "robotics-sim"
  }

  base_param_path = {
    bucket_name             = "${local.prefix}/bucket-name"
    base_ami_id             = "${local.prefix}/base-ami-id"
    isaac_snapshot_id       = "${local.prefix}/isaac-snapshot-id"
    project_prefix          = "${local.prefix}/config/project-prefix"
    workspace_path          = "${local.prefix}/config/workspace-path"
    gazebo_instance_types   = "${local.prefix}/config/gazebo-instance-types"
    isaac_instance_types    = "${local.prefix}/config/isaac-instance-types"
    isaac_webrtc_tcp_ports  = "${local.prefix}/config/isaac-webrtc-tcp-ports"
    isaac_webrtc_udp_ports  = "${local.prefix}/config/isaac-webrtc-udp-ports"
    elastic_ip_allocation_id = "${local.prefix}/config/elastic-ip-allocation-id"
  }

  gazebo_tag_specifications = [
    {
      resource_type = "instance"
      tags = merge(local.common_tags, {
        Mode = "gazebo"
      })
    },
    {
      resource_type = "volume"
      tags = merge(local.common_tags, {
        Mode = "gazebo"
      })
    }
  ]

  isaac_tag_specifications = [
    {
      resource_type = "instance"
      tags = merge(local.common_tags, {
        Mode = "isaac"
      })
    },
    {
      resource_type = "volume"
      tags = merge(local.common_tags, {
        Mode = "isaac"
      })
    }
  ]

  runtime_launch_template_name = var.simulation_mode == "isaac" ? aws_launch_template.isaac.name : aws_launch_template.gazebo.name
  runtime_security_group_id    = var.simulation_mode == "isaac" ? aws_security_group.isaac.id : aws_security_group.gazebo.id
  runtime_instance_type        = var.simulation_mode == "isaac" ? var.isaac_instance_types[0] : var.gazebo_instance_types[0]

  tcp_port_rules = flatten([
    for spec in var.isaac_webrtc_tcp_ports : (
      length(split("-", trimspace(spec))) == 2 ?
      [{
        from_port = tonumber(split("-", trimspace(spec))[0])
        to_port   = tonumber(split("-", trimspace(spec))[1])
      }] :
      [{
        from_port = tonumber(trimspace(spec))
        to_port   = tonumber(trimspace(spec))
      }]
    )
  ])

  udp_port_rules = flatten([
    for spec in var.isaac_webrtc_udp_ports : (
      length(split("-", trimspace(spec))) == 2 ?
      [{
        from_port = tonumber(split("-", trimspace(spec))[0])
        to_port   = tonumber(split("-", trimspace(spec))[1])
      }] :
      [{
        from_port = tonumber(trimspace(spec))
        to_port   = tonumber(trimspace(spec))
      }]
    )
  ])
}
