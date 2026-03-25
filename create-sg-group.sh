#!/usr/bin/env bash
set -euo pipefail

REGION="${REGION:-us-east-1}"
SG_NAME="ssh-dcv-sg"
DESCRIPTION="Allow SSH and Amazon DCV"

MY_IP="$(curl -fsSL https://checkip.amazonaws.com | tr -d '\n')"
MY_IP_CIDR="${MY_IP}/32"

VPC_ID="$(aws ec2 describe-vpcs \
  --region "$REGION" \
  --filters Name=isDefault,Values=true \
  --query 'Vpcs[0].VpcId' \
  --output text)"

if [ "$VPC_ID" = "None" ] || [ -z "$VPC_ID" ]; then
  echo "No default VPC found in region $REGION" >&2
  exit 1
fi

echo "Region: $REGION"
echo "Public IP: $MY_IP_CIDR"
echo "Default VPC: $VPC_ID"

SG_ID="$(aws ec2 create-security-group \
  --group-name "$SG_NAME" \
  --description "$DESCRIPTION" \
  --vpc-id "$VPC_ID" \
  --region "$REGION" \
  --query 'GroupId' \
  --output text)"

aws ec2 authorize-security-group-ingress \
  --group-id "$SG_ID" \
  --region "$REGION" \
  --ip-permissions \
    "IpProtocol=tcp,FromPort=22,ToPort=22,IpRanges=[{CidrIp=${MY_IP_CIDR},Description=\"SSH from my IP\"}]" \
    "IpProtocol=tcp,FromPort=8443,ToPort=8443,IpRanges=[{CidrIp=${MY_IP_CIDR},Description=\"DCV TCP from my IP\"}]" \
    "IpProtocol=udp,FromPort=8443,ToPort=8443,IpRanges=[{CidrIp=${MY_IP_CIDR},Description=\"DCV UDP from my IP\"}]"

echo "Created security group: $SG_ID"

aws ec2 describe-security-groups \
  --group-ids "$SG_ID" \
  --region "$REGION" \
  --query 'SecurityGroups[0].IpPermissions' \
  --output table
