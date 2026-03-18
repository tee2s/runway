#!/usr/bin/env bash
set -euo pipefail

bucket="${1:?bucket required}"
prefix="${2:-project/}"
workspace="${3:-/workspace/project}"

mkdir -p "$workspace"
aws s3 sync "$workspace" "s3://${bucket}/${prefix}" --delete
