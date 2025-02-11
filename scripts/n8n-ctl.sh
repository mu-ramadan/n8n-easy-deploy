#!/usr/bin/env bash
# n8n-ctl.sh - Main control script for n8n Easy Deploy.
# This script loads the functions and starts the CLI interface.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/functions.sh"
main "$@"
