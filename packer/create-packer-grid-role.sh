#!/usr/bin/env bash
set -euo pipefail

export AWS_PAGER=""

POLICY_NAME="packer-s3-grid-drivers-read"
ROLE_NAME="packer-grid-builder-role"
INSTANCE_PROFILE_NAME="packer-grid-builder-profile"

WORKDIR="$(mktemp -d)"
cleanup() {
  rm -rf "${WORKDIR}"
}
trap cleanup EXIT

echo "[setup] Checking AWS caller identity..."
CALLER_ARN="$(aws sts get-caller-identity --query Arn --output text --no-cli-pager)"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text --no-cli-pager)"

echo "[setup] Caller: ${CALLER_ARN}"
echo "[setup] Account ID: ${ACCOUNT_ID}"

cat > "${WORKDIR}/grid-s3-read-policy.json" <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ListDriverBucket",
      "Effect": "Allow",
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::ec2-linux-nvidia-drivers"
    },
    {
      "Sid": "GetDriverObjects",
      "Effect": "Allow",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::ec2-linux-nvidia-drivers/*"
    }
  ]
}
EOF

cat > "${WORKDIR}/ec2-trust-policy.json" <<'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

POLICY_ARN="arn:aws:iam::${ACCOUNT_ID}:policy/${POLICY_NAME}"

echo "[setup] Ensuring policy exists: ${POLICY_NAME}"
if aws iam get-policy --policy-arn "${POLICY_ARN}" --no-cli-pager >/dev/null 2>&1; then
  echo "[setup] Policy already exists."
else
  aws iam create-policy \
    --policy-name "${POLICY_NAME}" \
    --policy-document "file://${WORKDIR}/grid-s3-read-policy.json" \
    --query 'Policy.Arn' \
    --output text \
    --no-cli-pager >/dev/null
  echo "[setup] Policy created."
fi

echo "[setup] Ensuring role exists: ${ROLE_NAME}"
if aws iam get-role --role-name "${ROLE_NAME}" --no-cli-pager >/dev/null 2>&1; then
  echo "[setup] Role already exists."
else
  aws iam create-role \
    --role-name "${ROLE_NAME}" \
    --assume-role-policy-document "file://${WORKDIR}/ec2-trust-policy.json" \
    --query 'Role.Arn' \
    --output text \
    --no-cli-pager >/dev/null
  echo "[setup] Role created."
fi

echo "[setup] Ensuring policy is attached to role..."
ATTACHED_POLICY_ARN="$(
  aws iam list-attached-role-policies \
    --role-name "${ROLE_NAME}" \
    --query "AttachedPolicies[?PolicyArn=='${POLICY_ARN}'].PolicyArn" \
    --output text \
    --no-cli-pager
)"
if [[ "${ATTACHED_POLICY_ARN}" == "${POLICY_ARN}" ]]; then
  echo "[setup] Policy already attached."
else
  aws iam attach-role-policy \
    --role-name "${ROLE_NAME}" \
    --policy-arn "${POLICY_ARN}" \
    --no-cli-pager
  echo "[setup] Policy attached."
fi

echo "[setup] Ensuring instance profile exists: ${INSTANCE_PROFILE_NAME}"
if aws iam get-instance-profile \
  --instance-profile-name "${INSTANCE_PROFILE_NAME}" \
  --no-cli-pager >/dev/null 2>&1; then
  echo "[setup] Instance profile already exists."
else
  aws iam create-instance-profile \
    --instance-profile-name "${INSTANCE_PROFILE_NAME}" \
    --query 'InstanceProfile.Arn' \
    --output text \
    --no-cli-pager >/dev/null
  echo "[setup] Instance profile created."
fi

echo "[setup] Ensuring role is in instance profile..."
PROFILE_ROLE_NAME="$(
  aws iam get-instance-profile \
    --instance-profile-name "${INSTANCE_PROFILE_NAME}" \
    --query "InstanceProfile.Roles[?RoleName=='${ROLE_NAME}'].RoleName" \
    --output text \
    --no-cli-pager
)"
if [[ "${PROFILE_ROLE_NAME}" == "${ROLE_NAME}" ]]; then
  echo "[setup] Role already present in instance profile."
else
  aws iam add-role-to-instance-profile \
    --instance-profile-name "${INSTANCE_PROFILE_NAME}" \
    --role-name "${ROLE_NAME}" \
    --no-cli-pager
  echo "[setup] Role added to instance profile."
fi

echo
echo "[setup] Done."
echo "[setup] Policy ARN: ${POLICY_ARN}"
echo "[setup] Role name: ${ROLE_NAME}"
echo "[setup] Instance profile name: ${INSTANCE_PROFILE_NAME}"
