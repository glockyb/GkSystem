#!/bin/bash

# Exit on error
set -e

# Colors for output
GREEN="\033[0;32m"
RED="\033[0;31m"
NC="\033[0m" # No Color

# Check if the script is run as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root or use sudo.${NC}"
    exit 1
fi

# Check if lsb_release is installed
if ! command -v lsb_release &> /dev/null; then
    echo -e "${GREEN}Installing lsb-release...${NC}"
    apt-get update && apt-get install -y lsb-release
fi

# Check if the OS is Ubuntu
OS=$(lsb_release -is)
if [ "$OS" != "Ubuntu" ]; then
    echo -e "${RED}This script only supports Ubuntu.${NC}"
    exit 1
fi

# Check Ubuntu version
VERSION=$(lsb_release -rs)
if [[ "$VERSION" < "16.04" ]]; then
    echo -e "${RED}Ubuntu version must be 16.04 or higher.${NC}"
    exit 1
fi

# Uninstall old versions of Docker
echo -e "${GREEN}Removing old versions of Docker...${NC}"
apt-get remove -y docker docker-engine docker.io containerd runc || true

# Update package index
echo -e "${GREEN}Updating package index...${NC}"
apt-get update

# Install prerequisites
echo -e "${GREEN}Installing prerequisites...${NC}"
apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common \
    gnupg

# Add Docker's official GPG key
echo -e "${GREEN}Adding Docker's GPG key...${NC}"
if ! curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg; then
    echo -e "${RED}Failed to add Docker's GPG key.${NC}"
    exit 1
fi

# Set up the stable repository
echo -e "${GREEN}Setting up Docker repository...${NC}"
echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update package index again
echo -e "${GREEN}Updating package index...${NC}"
apt-get update

# Install Docker Engine
echo -e "${GREEN}Installing Docker Engine...${NC}"
apt-get install -y docker-ce docker-ce-cli containerd.io

# Verify Docker installation
echo -e "${GREEN}Verifying Docker installation...${NC}"
if ! docker --version &> /dev/null; then
    echo -e "${RED}Docker installation failed.${NC}"
    exit 1
fi

# Add current user to the docker group
echo -e "${GREEN}Adding user to the docker group...${NC}"
usermod -aG docker $SUDO_USER || true
echo -e "${GREEN}Please log out and log back in or run 'newgrp docker' to apply group changes.${NC}"

# Install Docker Compose as a plugin
echo -e "${GREEN}Installing Docker Compose...${NC}"
DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep -Po '"tag_name": "\K.*?(?=")')
if ! apt-get install -y docker-compose-plugin; then
    echo -e "${RED}Failed to install Docker Compose plugin.${NC}"
    exit 1
fi

# Verify Docker Compose installation
echo -e "${GREEN}Verifying Docker Compose installation...${NC}"
if ! docker compose version &> /dev/null; then
    echo -e "${RED}Docker Compose installation failed.${NC}"
    exit 1
fi

# Check Docker service status
echo -e "${GREEN}Checking Docker service status...${NC}"
if systemctl is-active --quiet docker; then
    echo -e "${GREEN}Docker is running.${NC}"
else
    echo -e "${RED}Docker is not running. Starting Docker...${NC}"
    systemctl start docker
fi

echo -e "${GREEN}Docker and Docker Compose installation completed successfully!${NC}"
