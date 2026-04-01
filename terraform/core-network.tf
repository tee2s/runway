data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-vpc"
  })
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-igw"
  })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-public-rt"
  })
}

resource "aws_subnet" "public" {
  for_each = {
    for idx, az in slice(data.aws_availability_zones.available.names, 0, 2) :
    idx => az
  }

  vpc_id                  = aws_vpc.main.id
  availability_zone       = each.value
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, tonumber(each.key))
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-public-${each.value}"
  })
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "gazebo" {
  name        = "${var.project_name}-gazebo-sg"
  description = "Security group for Gazebo simulation instances"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-gazebo-sg"
  })
}

resource "aws_security_group" "isaac" {
  name        = "${var.project_name}-isaac-sg"
  description = "Security group for Isaac simulation instances"
  vpc_id      = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-isaac-sg"
  })
}

resource "aws_vpc_security_group_ingress_rule" "gazebo_ssh" {
  security_group_id = aws_security_group.gazebo.id
  cidr_ipv4         = var.allowed_ssh_cidr
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
  description       = "SSH"
}

resource "aws_vpc_security_group_ingress_rule" "gazebo_dcv" {
  security_group_id = aws_security_group.gazebo.id
  cidr_ipv4         = var.allowed_ssh_cidr
  from_port         = 8443
  ip_protocol       = "tcp"
  to_port           = 8443
  description       = "NICE DCV"
}

resource "aws_vpc_security_group_ingress_rule" "isaac_ssh" {
  security_group_id = aws_security_group.isaac.id
  cidr_ipv4         = var.allowed_ssh_cidr
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
  description       = "SSH"
}

resource "aws_vpc_security_group_ingress_rule" "isaac_dcv" {
  security_group_id = aws_security_group.isaac.id
  cidr_ipv4         = var.allowed_ssh_cidr
  from_port         = 8443
  ip_protocol       = "tcp"
  to_port           = 8443
  description       = "NICE DCV"
}

resource "aws_vpc_security_group_ingress_rule" "isaac_tcp_webrtc" {
  for_each = {
    for idx, rule in local.tcp_port_rules :
    idx => rule
  }

  security_group_id = aws_security_group.isaac.id
  cidr_ipv4         = var.allowed_ssh_cidr
  from_port         = each.value.from_port
  ip_protocol       = "tcp"
  to_port           = each.value.to_port
  description       = "Isaac WebRTC TCP ${each.value.from_port}-${each.value.to_port}"
}

resource "aws_vpc_security_group_ingress_rule" "isaac_udp_webrtc" {
  for_each = {
    for idx, rule in local.udp_port_rules :
    idx => rule
  }

  security_group_id = aws_security_group.isaac.id
  cidr_ipv4         = var.allowed_ssh_cidr
  from_port         = each.value.from_port
  ip_protocol       = "udp"
  to_port           = each.value.to_port
  description       = "Isaac WebRTC UDP ${each.value.from_port}-${each.value.to_port}"
}
