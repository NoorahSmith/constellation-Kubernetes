#!/usr/bin/env bash
# Copyright (c) Edgeless Systems GmbH
#
# SPDX-License-Identifier: AGPL-3.0-only

set -euo pipefail
shopt -s inherit_errexit

# parsing of the command line arguments. check if argv[1] is --debug
verbosity=0
if [[ $# -gt 0 ]]; then
  if [[ $1 == "--debug" ]]; then
    verbosity=-1
    echo "[Constellation] Debug mode enabled"
  else
    echo "[Constellation] Unknown argument: $1"
    exit 1
  fi
else
  echo "[Constellation] Debug mode disabled"
fi

# Prepare the encrypted volume by either initializing it with a random key or by aquiring the key from another bootstrapper.
# Store encryption key (random or recovered key) in /run/cryptsetup-keys.d/state.key
disk-mapper \
  -csp "${CONSTEL_CSP}" \
  -v "${verbosity}"

if [[ $? -ne 0 ]]; then
  echo "Failed to prepare state disk"
  sleep 2 # give the serial console time to print the error message
  exit $? # exit with the same error code as disk-mapper
fi
