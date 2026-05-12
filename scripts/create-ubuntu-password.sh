#!/usr/bin/env bash
set -euo pipefail

PARAM_NAME="${PARAM_NAME:-/ubuntu-default-password-hash}"
AWS_REGION="${AWS_REGION:-us-east-1}"
KEYCHAIN_SERVICE="${KEYCHAIN_SERVICE:-dcv-robotics-dev}"
KEYCHAIN_ACCOUNT="${KEYCHAIN_ACCOUNT:-ubuntu}"
MAX_ATTEMPTS=3

echo "This will create a password for the default Ubuntu user"
echo "and store its hash in AWS SSM Parameter Store."
if [[ "$(uname -s)" == "Darwin" ]]; then
  echo "It will also store the plaintext DCV password in macOS Keychain"
  echo "so scripts/launch-dcv.sh can open the generated connection file."
fi
echo
echo "Parameter: $PARAM_NAME"
echo "Region:    $AWS_REGION"
if [[ "$(uname -s)" == "Darwin" ]]; then
  echo "Keychain:  service=$KEYCHAIN_SERVICE account=$KEYCHAIN_ACCOUNT"
fi
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

if [[ "$(uname -s)" == "Darwin" ]]; then
  security add-generic-password \
    -U \
    -a "$KEYCHAIN_ACCOUNT" \
    -s "$KEYCHAIN_SERVICE" \
    -w "$UBUNTU_PASS"
fi

unset UBUNTU_PASS UBUNTU_PASS_CONFIRM

echo
echo "Success: stored the Ubuntu password hash in AWS SSM Parameter Store."
echo "SSM parameter: $PARAM_NAME"
if [[ "$(uname -s)" == "Darwin" ]]; then
  echo "Success: stored the plaintext DCV password in macOS Keychain."
  echo "Keychain item: service=$KEYCHAIN_SERVICE account=$KEYCHAIN_ACCOUNT"
fi
