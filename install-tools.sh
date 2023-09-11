#!/bin/bash

# Define log file and colors
LOG_FILE="install-tools.log"
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

cat /dev/null > $LOG_FILE

log_and_run() {
  echo "Running: $@" >> $LOG_FILE
  eval "$@" >> $LOG_FILE 2>&1
}

echo -e "${YELLOW}Logging install steps to $LOG_FILE${NC}"

install_common() {
  # Install AWS CLI
  if ! command -v aws &> /dev/null; then
    echo -e "Installing ${GREEN}AWS CLI${NC}..."
    log_and_run "sudo curl 'https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip' -o 'awscliv2.zip'"
    log_and_run "sudo unzip -o -q awscliv2.zip"
    log_and_run "sudo ./aws/install --install-dir /usr/local/aws-cli --bin-dir /usr/local/bin"
    log_and_run "sudo rm -rf awscliv2.zip aws"
  else
    echo -e "${YELLOW}AWS CLI${NC} is already installed, updating to latest version..."
    log_and_run "sudo curl 'https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip' -o 'awscliv2.zip'"
    log_and_run "sudo unzip -o -q awscliv2.zip"
    log_and_run "sudo ./aws/install --install-dir /usr/local/aws-cli --bin-dir /usr/local/bin --update"
    log_and_run "sudo rm -rf awscliv2.zip aws"
  fi

  # Terraform
  LATEST_TERRAFORM=$(curl -s https://checkpoint-api.hashicorp.com/v1/check/terraform | jq -r .current_version)
  if ! command -v terraform > /dev/null || [[ "$(terraform version | head -n 1 | cut -d 'v' -f 2)" != "${LATEST_TERRAFORM}" ]]; then
    echo -e "Installing ${GREEN}Terraform${NC}..."
    log_and_run "wget https://releases.hashicorp.com/terraform/${LATEST_TERRAFORM}/terraform_${LATEST_TERRAFORM}_linux_amd64.zip"
    log_and_run "unzip terraform_${LATEST_TERRAFORM}_linux_amd64.zip"
    log_and_run "sudo mv terraform /usr/local/bin/"
    log_and_run "rm terraform_${LATEST_TERRAFORM}_linux_amd64.zip"
  else
    echo -e "${YELLOW}Terraform${NC} is already at the latest version."
  fi

  # Install kubectl
  if ! command -v kubectl &> /dev/null; then
    echo -e "Installing ${GREEN}kubectl${NC}..."
    log_and_run "sudo curl -LO https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    log_and_run "sudo chmod +x ./kubectl"
    log_and_run "sudo mv ./kubectl /usr/local/bin/kubectl"
  else
    echo -e "${YELLOW}kubectl${NC} is already installed."
  fi

  # Install Helm
  if ! command -v helm &> /dev/null; then
    echo -e "Installing ${GREEN}Helm${NC}..."
    log_and_run "sudo curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3"
    log_and_run "sudo chmod 700 get_helm.sh"
    log_and_run "sudo ./get_helm.sh"
  else
    echo -e "${YELLOW}Helm${NC} is already installed."
  fi

  # Install k9s for Linux
  LATEST_K9S_TAG=$(curl -s https://api.github.com/repos/derailed/k9s/releases/latest | jq -r .tag_name)
  if ! command -v k9s &> /dev/null; then
    echo -e "Installing ${GREEN}k9s${NC}..."
    K9S_RELEASE_URL="https://github.com/derailed/k9s/releases/download/${LATEST_K9S_TAG}/k9s_Linux_amd64.tar.gz"
    log_and_run "curl -L ${K9S_RELEASE_URL} | tar xvz -C /tmp/"
    log_and_run "sudo mv /tmp/k9s /usr/local/bin/"
    log_and_run "rm -rf /tmp/k9s*"
  else
    echo -e "${YELLOW}k9s${NC} is already at the latest version."
  fi
}

# macOS specific installations
if [[ "$OSTYPE" == "darwin"* ]]; then
  echo -e "${GREEN}Detected macOS, installing tools...${NC}"
  log_and_run "brew install awscli terraform kubectl helm k9s"
elif command -v apt-get > /dev/null; then
  log_and_run "sudo apt-get update -qq"
  install_common
elif command -v apt-get > /dev/null; then
  log_and_run "sudo apt-get update -qq"
  install_common
elif command -v yum > /dev/null; then
  log_and_run "sudo yum update -y -q"
  install_common
else
  echo -e "${RED}No known package manager found.${NC}"
  exit 1
fi

echo -e "${GREEN}All required tools are installed.${NC}"
