#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Function to check if a command exists and install if not
check_install() {
  local name=$1
  local command=$2
  local install_command=$3
  if $command &> /dev/null
  then
    echo -e "${GREEN}- $name is installed ${NC}\n"
  else
    echo -e "${YELLOW}- $name is not installed. Installing...${NC}\n"
    eval $install_command
  fi
}