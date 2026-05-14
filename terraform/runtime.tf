resource "aws_ec2_fleet" "runtime" {
  count = var.runtime_enabled ? 1 : 0

  type                = "instant"
  terminate_instances = true

  launch_template_config {
    launch_template_specification {
      launch_template_id = local.runtime_launch_template_id
      version            = "$Latest"
    }

    dynamic "override" {
      for_each = local.runtime_fleet_overrides

      content {
        instance_type = override.value.instance_type
        subnet_id     = override.value.subnet_id
      }
    }
  }

  target_capacity_specification {
    default_target_capacity_type = "spot"
    total_target_capacity        = 1
  }

  spot_options {
    allocation_strategy            = "price-capacity-optimized"
    instance_interruption_behavior = "terminate"
    min_target_capacity            = 1
    single_availability_zone       = true
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.simulation_mode}-runtime-fleet"
    Mode = var.simulation_mode
    Role = "runtime-fleet"
  })
}

data "aws_instance" "runtime" {
  count = var.runtime_enabled ? 1 : 0

  filter {
    name   = "tag:Role"
    values = ["runtime"]
  }

  filter {
    name   = "tag:Mode"
    values = [var.simulation_mode]
  }

  filter {
    name   = "tag:Project"
    values = [var.project_name]
  }

  filter {
    name   = "instance-state-name"
    values = ["running", "pending"]
  }

  depends_on = [aws_ec2_fleet.runtime]
}

data "aws_ec2_spot_price" "runtime" {
  count = var.runtime_enabled ? 1 : 0

  instance_type     = local.runtime_instance_type
  availability_zone = local.runtime_availability_zone

  filter {
    name   = "product-description"
    values = ["Linux/UNIX"]
  }

  depends_on = [data.aws_instance.runtime]
}

resource "aws_ebs_volume" "isaac_runtime" {
  count = var.runtime_enabled && var.simulation_mode == "isaac" ? 1 : 0

  availability_zone = local.runtime_availability_zone
  snapshot_id       = trimspace(var.isaac_snapshot_id) != "" ? var.isaac_snapshot_id : null
  size              = trimspace(var.isaac_snapshot_id) == "" ? var.isaac_data_volume_size_gib : null
  type              = "gp3"
  encrypted         = true

  tags = merge(local.common_tags, {
    Role = "isaac-runtime"
  })
}

resource "aws_volume_attachment" "isaac_runtime" {
  count = var.runtime_enabled && var.simulation_mode == "isaac" ? 1 : 0

  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.isaac_runtime[0].id
  instance_id = local.runtime_instance_id
}