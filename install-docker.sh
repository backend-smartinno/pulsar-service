#!/bin/bash

# Exit on error
set -e

echo "Updating package list..."
sudo apt-get update

# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "Adding current user to the Docker group (log out and back in for this to take effect)..."
sudo groupadd docker
sudo usermod -aG docker $USER
newgrp docker

echo "Starting and enabling Docker service..."
sudo systemctl enable docker.service
sudo systemctl enable containerd.service

echo "Installation complete! Run 'docker --version' to check the installation."
echo "You may need to restart your system for group changes to take effect."
