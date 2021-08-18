#!/usr/bin/env bash

PASSWORD=$(/usr/bin/openssl passwd -crypt 'password')

# Vagrant-specific configuration
/usr/bin/useradd --password ${PASSWORD} --comment 'Vagrant User' --create-home --user-group vagrant
echo -e 'vagrant\nvagrant' | /usr/bin/passwd vagrant 
echo 'Defaults env_keep += "SSH_AUTH_SOCK"' | tee /etc/sudoers.d/10_vagrant
echo 'vagrant ALL=(ALL) NOPASSWD: ALL' | tee -a /etc/sudoers.d/10_vagrant
/usr/bin/chmod 0440 /etc/sudoers.d/10_vagrant
/usr/bin/systemctl start sshd.service
