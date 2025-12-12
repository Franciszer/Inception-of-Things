#!/bin/bash
set -eux

# Install GitLab CE on the VM
curl https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.deb.sh | sudo bash

sudo EXTERNAL_URL="http://192.168.56.150" apt-get install -y gitlab-ce

# Make sure GitLab is running
gitlab-ctl reconfigure
