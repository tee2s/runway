resource "aws_instance" "runtime" {
  count = var.runtime_enabled ? 1 : 0

  subnet_id                   = values(aws_subnet.public)[0].id
  vpc_security_group_ids      = [local.runtime_security_group_id]
  associate_public_ip_address = true
  instance_type               = local.runtime_instance_type

  launch_template {
    name    = local.runtime_launch_template_name
    version = "$Latest"
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.simulation_mode}-runtime"
    Mode = var.simulation_mode
    Role = "runtime"
  })
}

resource "aws_ebs_volume" "isaac_runtime" {
  count = var.runtime_enabled && var.simulation_mode == "isaac" ? 1 : 0

  availability_zone = aws_instance.runtime[0].availability_zone
  snapshot_id       = var.isaac_snapshot_id
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
  instance_id = aws_instance.runtime[0].id
}

resource "aws_eip_association" "runtime" {
  count = var.runtime_enabled && var.enable_elastic_ip ? 1 : 0

  instance_id   = aws_instance.runtime[0].id
  allocation_id = aws_eip.simulation[0].id
}
