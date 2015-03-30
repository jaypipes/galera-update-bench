#!/usr/bin/env bash
# NOTE(jaypipes): This only tested on Ubuntu 14.04.

set -xe

BASE_DIR=$(cd $(dirname "$0"); pwd)
ANSIBLE_DIR=$( cd "$BASE_DIR/../ansible"; pwd)
SSH_KEY=${SSH_KEY:-"$HOME/.ssh/id_rsa.pub"}

echo "Installing Ansible, LXC and all dependencies..."

if [[ ! `which ansible` ]]; then
    # Check that ansible is installed and if not, install it and its dependencies.
    sudo apt-add-repository -y ppa:ansible/ansible
    sudo apt-get update
    sudo apt-get -y install git python-all python-dev curl autoconf\
        g++ python2.7-dev software-properties-common ansible\
        lxc lxc-templates cloud-image-utils cloud-utils debootstrap cdebootstrap
fi

if [[ ! `sudo lxc-info -n base-container` ]]; then
    echo "Creating base LXC container..."

    sudo lxc-create -n base-container -t ubuntu-cloud -- --release=trusty --auth-key=$SSH_KEY
fi

echo "Creating LXC containers for Galera cluster..."

sudo lxc-clone -o base-container -n galera1 -- --auth-key=$SSH_KEY
sudo lxc-clone -o base-container -n galera2 -- --auth-key=$SSH_KEY
sudo lxc-clone -o base-container -n galera3 -- --auth-key=$SSH_KEY

echo "Starting Galera containers..."

sudo lxc-start -n galera1 -d
sudo lxc-start -n galera2 -d
sudo lxc-start -n galera3 -d

echo "Collecting Galera container IP addresses..."

sleep 30

GALERA1_IP=`sudo lxc-info -i -H -n galera1`
GALERA2_IP=`sudo lxc-info -i -H -n galera2`
GALERA3_IP=`sudo lxc-info -i -H -n galera3`

cat > "$ANSIBLE_DIR/hosts" <<EOF
[galera]
$GALERA1_IP galera_bootstrap=1
$GALERA2_IP
$GALERA3_IP
EOF

sudo lxc-ls --fancy

echo "Adding host keys for LXC containers..."

ssh-keyscan -H $GALERA1_IP >> $HOME/.ssh/known_hosts
ssh-keyscan -H $GALERA2_IP >> $HOME/.ssh/known_hosts
ssh-keyscan -H $GALERA3_IP >> $HOME/.ssh/known_hosts
