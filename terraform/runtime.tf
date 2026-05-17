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

data "aws_ebs_volumes" "dev_state" {
  count = var.dev_state_volume_enabled ? 1 : 0

  filter {
    name   = "tag:Role"
    values = ["dev-state"]
  }
  filter {
    name   = "tag:Project"
    values = [var.project_name]
  }
  filter {
    name   = "status"
    values = ["available", "in-use"]
  }
}

data "aws_ebs_volume" "dev_state_existing" {
  count = var.dev_state_volume_enabled && length(try(data.aws_ebs_volumes.dev_state[0].ids, [])) > 0 ? 1 : 0

  most_recent = true
  filter {
    name   = "volume-id"
    values = [tolist(data.aws_ebs_volumes.dev_state[0].ids)[0]]
  }
}

data "aws_ssm_parameter" "dev_state_snapshot_id" {
  count = var.dev_state_volume_enabled ? 1 : 0
  name  = local.base_param_path.dev_state_snapshot_id

  depends_on = [aws_ssm_parameter.dev_state_snapshot_id]
}

locals {
  dev_state_current_snapshot_id = try(trimspace(data.aws_ssm_parameter.dev_state_snapshot_id[0].value), "")
}

resource "aws_ebs_volume" "dev_state" {
  count = var.dev_state_volume_enabled && (var.persist_dev_state_volume || var.runtime_enabled) ? 1 : 0

  availability_zone = var.persist_dev_state_volume ? aws_subnet.public["0"].availability_zone : local.runtime_availability_zone

  lifecycle {
    ignore_changes = [availability_zone]
  }
  snapshot_id       = local.dev_state_current_snapshot_id != "" ? local.dev_state_current_snapshot_id : null
  size              = local.dev_state_current_snapshot_id == "" ? var.dev_state_volume_size_gib : null
  type              = var.dev_state_volume_type
  encrypted         = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-dev-state"
    Role = "dev-state"
  })
}

resource "aws_volume_attachment" "dev_state" {
  count = var.dev_state_volume_enabled && var.runtime_enabled ? 1 : 0

  device_name  = "/dev/sdg"
  volume_id    = aws_ebs_volume.dev_state[0].id
  instance_id  = local.runtime_instance_id
  force_detach = true
}

resource "terraform_data" "dev_state_auto_save" {
  count = var.dev_state_auto_save && !var.persist_dev_state_volume && var.dev_state_volume_enabled && var.runtime_enabled ? 1 : 0

  input = {
    instance_id       = local.runtime_instance_id
    snapshot_id_param = local.base_param_path.dev_state_snapshot_id
    region            = var.region
  }

  provisioner "local-exec" {
    when       = destroy
    on_failure = continue
    command    = <<-SCRIPT
      set -e
      INSTANCE_ID="${self.input.instance_id}"
      REGION="${self.input.region}"
      SNAPSHOT_PARAM="${self.input.snapshot_id_param}"

      echo "[auto-save] Sending snapshot-dev-state to $INSTANCE_ID..."
      COMMAND_ID=$(aws ssm send-command \
        --region "$REGION" \
        --instance-id "$INSTANCE_ID" \
        --document-name "AWS-RunShellScript" \
        --parameters 'commands=["sudo /usr/local/bin/snapshot-dev-state"],executionTimeout=["3600"]' \
        --output text \
        --query "Command.CommandId")

      echo "[auto-save] Command $COMMAND_ID dispatched, polling..."
      for i in $(seq 1 60); do
        STATUS=$(aws ssm get-command-invocation \
          --region "$REGION" \
          --command-id "$COMMAND_ID" \
          --instance-id "$INSTANCE_ID" \
          --query "Status" \
          --output text 2>/dev/null || echo "Pending")
        case "$STATUS" in
          Success)
            SNAPSHOT_ID=$(aws ssm get-parameter \
              --region "$REGION" \
              --name "$SNAPSHOT_PARAM" \
              --query "Parameter.Value" \
              --output text)
            echo "[auto-save] Complete: $SNAPSHOT_ID"
            exit 0
            ;;
          Failed|Cancelled|TimedOut|Cancelling)
            echo "[auto-save] Command failed with status: $STATUS"
            aws ssm get-command-invocation \
              --region "$REGION" \
              --command-id "$COMMAND_ID" \
              --instance-id "$INSTANCE_ID" \
              --query "StandardErrorContent" \
              --output text || true
            exit 1
            ;;
        esac
        echo "[auto-save] Status: $STATUS (poll $i/60)"
        sleep 30
      done
      echo "[auto-save] Timed out after 30 minutes"
      exit 1
    SCRIPT
  }

  depends_on = [
    aws_ec2_fleet.runtime,
    aws_volume_attachment.dev_state,
  ]
}

resource "aws_ssm_parameter" "dev_state_volume_id" {
  count = var.dev_state_volume_enabled && var.runtime_enabled ? 1 : 0

  name      = local.base_param_path.dev_state_volume_id
  type      = "String"
  value     = aws_ebs_volume.dev_state[0].id
  overwrite = true

  tags = local.common_tags
}