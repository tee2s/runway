data "aws_caller_identity" "current" {}

resource "aws_iam_role" "sim_instance" {
  name               = "${var.project_name}-sim-instance-role"
  description        = "Role for robotics simulation instances"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.sim_instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "sim_instance_inline" {
  name = "${var.project_name}-sim-instance-inline-policy"
  role = aws_iam_role.sim_instance.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.project.arn,
          "${aws_s3_bucket.project.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:PutParameter"
        ]
        Resource = "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter${local.prefix}/*"
      },
      {
        Effect = "Allow"
        Action = "s3:GetObject"
        Resource = "arn:aws:s3:::dcv-license.${var.region}/*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "sim_instance" {
  name = "${var.project_name}-sim-instance-profile"
  role = aws_iam_role.sim_instance.name
}

resource "aws_launch_template" "gazebo" {
  name = "${var.project_name}-gazebo-lt"

  image_id      = var.base_ami_id
  instance_type = var.gazebo_launch_template_instance_type
  key_name      = var.runtime_key_pair_name
  user_data = base64encode(templatefile("${path.module}/templates/bootstrap.sh.tftpl", {
    mode               = "gazebo"
    project_prefix_param = local.base_param_path.project_prefix
    workspace_param    = local.base_param_path.workspace_path
    bucket_param       = local.base_param_path.bucket_name
  }))

  iam_instance_profile {
    name = aws_iam_instance_profile.sim_instance.name
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  instance_market_options {
    market_type = "spot"
    spot_options {
      instance_interruption_behavior = "terminate"
      spot_instance_type             = "one-time"
    }
  }

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size           = var.root_volume_size_gib
      volume_type           = "gp3"
      delete_on_termination = true
      encrypted             = true
    }
  }

  vpc_security_group_ids = [aws_security_group.gazebo.id]

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_tags, {
      Mode = "gazebo"
    })
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(local.common_tags, {
      Mode = "gazebo"
    })
  }

  tags = local.common_tags
}

resource "aws_launch_template" "isaac" {
  name = "${var.project_name}-isaac-lt"

  image_id      = var.base_ami_id
  instance_type = var.isaac_launch_template_instance_type
  key_name      = var.runtime_key_pair_name
  user_data = base64encode(templatefile("${path.module}/templates/bootstrap.sh.tftpl", {
    mode               = "isaac"
    project_prefix_param = local.base_param_path.project_prefix
    workspace_param    = local.base_param_path.workspace_path
    bucket_param       = local.base_param_path.bucket_name
  }))

  iam_instance_profile {
    name = aws_iam_instance_profile.sim_instance.name
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  instance_market_options {
    market_type = "spot"
    spot_options {
      instance_interruption_behavior = "terminate"
      spot_instance_type             = "one-time"
    }
  }

  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_size           = var.root_volume_size_gib
      volume_type           = "gp3"
      delete_on_termination = true
      encrypted             = true
    }
  }

  vpc_security_group_ids = [aws_security_group.isaac.id]

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_tags, {
      Mode = "isaac"
    })
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(local.common_tags, {
      Mode = "isaac"
    })
  }

  tags = local.common_tags
}

locals {
  ssm_values = merge(
    {
      (local.base_param_path.bucket_name)            = aws_s3_bucket.project.bucket
      (local.base_param_path.base_ami_id)            = var.base_ami_id
      (local.base_param_path.project_prefix)         = var.s3_project_prefix
      (local.base_param_path.workspace_path)         = var.workspace_path
      (local.base_param_path.isaac_webrtc_tcp_ports) = local.isaac_livestream_tcp_ports_ssm
      (local.base_param_path.isaac_webrtc_udp_ports) = local.isaac_livestream_udp_ports_ssm
    },
    trimspace(var.isaac_snapshot_id) != "" ? {
      (local.base_param_path.isaac_snapshot_id) = var.isaac_snapshot_id
    } : {}
  )
}

resource "aws_ssm_parameter" "infra" {
  for_each = local.ssm_values

  name      = each.key
  type      = "String"
  value     = each.value
  overwrite = true

  tags = local.common_tags
}
