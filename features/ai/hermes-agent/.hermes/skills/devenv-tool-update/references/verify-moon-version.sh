#!/usr/bin/env bash
# Verification script for moon version 2.5.0 in devenv shell

# Run moon version inside devenv shell and capture output
output=$(devenv shell -- moon --version 2>&1)
exit_code=$?

if [ $exit_code -ne 0 ]; then
  echo "Error: Failed to run moon version in devenv shell:"
  echo "$output"
  exit 1
fi

# Check if the output contains the expected version string
if echo "$output" | grep -q "moon 2.5.0"; then
  echo "Verification passed: moon version 2.5.0 found in output"
  exit 0
else
  echo "Verification failed: expected to find 'moon 2.5.0' in output:"
  echo "$output"
  exit 1
fi