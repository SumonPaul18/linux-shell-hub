#!/bin/bash
#Install using the Apt repository
# Add Docker's official GPG key:

sudo apt-get update -y
sudo apt-get install ca-certificates curl gnupg -y
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Add the repository to Apt sources:

echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update

#Install the Docker packages:

sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin -y

#Verify the Docker Version:

docker --version

# Add current user to the docker group to run Docker commands without sudo
sudo usermod -aG docker ${USER}


# Activate the changes to groups
su - ${USER}

# Enable Docker
sudo systemctl enable docker

# Verify Docker is installed and working
sudo systemctl status docker



