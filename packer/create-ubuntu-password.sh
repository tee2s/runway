#!/usr/bin/env bash
set -euo pipefail

PARAM_NAME="/ubuntu-default-password-hash"
AWS_REGION="us-east-1"
MAX_ATTEMPTS=3

echo "This will create a password for the default Ubuntu user"
echo "and store only its hash in AWS SSM Parameter Store."
echo
echo "Parameter: $PARAM_NAME"
echo "Region:    $AWS_REGION"
echo

attempt=1
while (( attempt <= MAX_ATTEMPTS )); do
  read -rsp "Create a password for the default Ubuntu user: " UBUNTU_PASS
  echo
  read -rsp "Confirm the password: " UBUNTU_PASS_CONFIRM
  echo

  if [[ -z "$UBUNTU_PASS" ]]; then
    echo "Error: the password cannot be empty."
  elif [[ "$UBUNTU_PASS" != "$UBUNTU_PASS_CONFIRM" ]]; then
    echo "Error: the passwords do not match."
  else
    break
  fi

  unset UBUNTU_PASS UBUNTU_PASS_CONFIRM

  if (( attempt == MAX_ATTEMPTS )); then
    echo "Error: failed to confirm the password after $MAX_ATTEMPTS attempts."
    exit 1
  fi

  echo "Please try again ($((MAX_ATTEMPTS - attempt)) attempt(s) remaining)."
  echo
  ((attempt++))
done

aws ssm put-parameter \
  --region "$AWS_REGION" \
  --name "$PARAM_NAME" \
  --type "SecureString" \
  --key-id "alias/aws/ssm" \
  --overwrite \
  --value "$(openssl passwd -6 "$UBUNTU_PASS")"

unset UBUNTU_PASS UBUNTU_PASS_CONFIRM

echo
echo "Success: stored the Ubuntu password hash in AWS SSM Parameter Store."
echo "SSM parameter: $PARAM_NAME"