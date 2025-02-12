#!/usr/bin/env bash
# n8n-ctl.sh - Main control script for n8n Easy Deploy.
# Loads the functions and launches the interactive menu.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/functions.sh"

# Display a hero banner and instructions, then start the menu
clear
cat << "EOF"
 _   _   _   _   _   _   _   _   _  
/ \ / \ / \ / \ / \ / \ / \ / \ / \ 
( n | 8 | n |   | E | a | s | y | D )
 \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ 
  _   _   _   _   _   _   _   _   _  
 / \ / \ / \ / \ / \ / \ / \ / \ / \ 
( e | p | l | o | y |   | T | o | o )
 \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ \_/ 
EOF
echo ""
echo "Welcome to n8n Easy Deploy!"
echo "This tool deploys, updates, backs up, and restores your self-hosted n8n instance."
echo "Make sure you've updated 'config/.env' with your settings (DOMAIN_NAME, LETSENCRYPT_EMAIL, etc.)."
echo ""
main "$@"
