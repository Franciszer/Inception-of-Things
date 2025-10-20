#!/usr/bin/env bash

# Define colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Function to check if a command exists and install if not
check_install() {
  local name=$1
  local cmd=$2
  local install_command=$3

  if [[ -z "$name" || -z "$cmd" || -z "$install_command" ]]; then
    printf "${RED}Error: Missing required parameters${NC}\n"
    return 1
  fi

  # Check if command exists
  if command -v "$cmd" &>/dev/null; then
    printf "${GREEN}✓ %s is already installed${NC}\n" "$name"
    return 0
  else
    printf "${YELLOW}⚠ %s is not installed. Installing...${NC}\n" "$name"
    
    if eval "$install_command"; then
      hash -r 2>/dev/null || true
      
      # Verify installation succeeded
      if command -v "$cmd" &>/dev/null; then
        printf "${GREEN}✓ %s has been successfully installed${NC}\n" "$name"
        return 0
      else
        printf "${RED}✗ %s installation completed but command '%s' not found${NC}\n" "$name" "$cmd"
        printf "${YELLOW}  Note: You may need to reload your shell or check the command name${NC}\n"
        return 1
      fi
    else
      printf "${RED}✗ Failed to install %s (exit code: $?)${NC}\n" "$name"
      return 1
    fi
  fi
}

# Ensure the script is run with sudo privileges
if [ "$(id -u)" -ne 0 ] && [ -z "$SUDO_UID" ] && [ -z "$SUDO_USER" ]; then
    printf "${RED}[LINUX]${NC} - Permission denied. Please run the command with sudo privileges.\n"
    exit 87
fi

#
##                              Docker
#

printf "${GREEN}[DOCKER]${NC} - Installing docker...\n"
check_install "docker" "docker" "apt-get install -y ca-certificates curl gnupg lsb-release && mkdir -m 0755 -p /etc/apt/keyrings && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && echo \"deb [arch=\$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \$(lsb_release -cs) stable\" | tee /etc/apt/sources.list.d/docker.list > /dev/null && apt-get update && apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin && usermod -aG docker \$USER"



#
##                              Curl
#
printf "${GREEN}[CURL]${NC} - Installing curl...\n"
check_install "curl" "curl" "apt-get install -y curl"


#
##                              kubectl
#

printf "${GREEN}[KUBECTL]${NC} - Installing kubectl...\n"
check_install "kubectl" "kubectl" "curl -LO https://dl.k8s.io/release/\$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl && chmod +x kubectl && mv kubectl /usr/local/bin/"

# kubectl alias
printf "${GREEN}[KUBECTL]${NC} - Creating aliases...\n"
if ! grep -q "alias k=kubectl" /etc/bash.bashrc; then
    echo "alias k=kubectl" >> /etc/bash.bashrc
    printf "${GREEN}✓ kubectl alias added${NC}\n"
else
    printf "${GREEN}✓ kubectl alias already exists${NC}\n"
fi

#
##                              k3d
#

printf "${GREEN}[K3D]${NC} - Installing k3d...\n"
wget -q -O - https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

printf "${GREEN}✓ Setup completed!${NC}\n"