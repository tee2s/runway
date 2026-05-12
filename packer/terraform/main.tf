# IAM for Packer grid image builds only: instance profile + role with read access to
# s3://ec2-linux-nvidia-drivers.
#
# Apply from repo root:
#   terraform -chdir=packer/terraform init
#   terraform -chdir=packer/terraform apply
#
# If packer-grid-builder-profile already exists from the shell script, import or remove it before apply.

locals {
  common_tags = {
    Project   = var.project_name
    ManagedBy = "terraform"
    Workload  = "packer-grid-build"
  }
}

data "aws_iam_policy_document" "packer_build_instance_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "packer_build_instance" {
  name               = "packer-build-instance-role"
  assume_role_policy = data.aws_iam_policy_document.packer_build_instance_trust.json
  tags               = merge(local.common_tags, { Purpose = "packer-build-instance" })
}

data "aws_iam_policy_document" "packer_build_instance_s3_drivers" {
  statement {
    sid       = "ListDriverBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::ec2-linux-nvidia-drivers"]
  }

  statement {
    sid       = "GetDriverObjects"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["arn:aws:s3:::ec2-linux-nvidia-drivers/*"]
  }
}

resource "aws_iam_role_policy" "packer_build_instance_s3_drivers" {
  name   = "packer-s3-grid-drivers-read"
  role   = aws_iam_role.packer_build_instance.id
  policy = data.aws_iam_policy_document.packer_build_instance_s3_drivers.json
}

resource "aws_iam_instance_profile" "packer_build_instance" {
  name = "packer-build-instance-profile"
  role = aws_iam_role.packer_build_instance.name
  tags = merge(local.common_tags, { Purpose = "packer-build-instance" })
}
