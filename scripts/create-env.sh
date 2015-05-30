#!/usr/bin/env bash
# NOTE(jaypipes): This tested on Ubuntu 14.04 and Ubuntu 14.10.

set -e

BASE_DIR=$(cd $(dirname "$0"); pwd)
ANSIBLE_DIR=$( cd "$BASE_DIR/../ansible"; pwd)
SSH_KEY=${SSH_KEY:-"$HOME/.ssh/id_rsa.pub"}


# Check that ansible is installed and if not, install it and its dependencies.
if [[ ! `which ansible` ]]; then
    # Ubuntu Utopic and beyond have Ansible available in the Ubuntu
    # package repositories. No need for the ansible PPA..
    if [[ `lsb_release -a 2>/dev/null | grep Codename | awk '{print $2}'` = 'trusty' ]]; then
        sudo apt-add-repository -y ppa:ansible/ansible
        sudo apt-get update
    fi
    echo "Installing Ansible, LXC and all dependencies..."
    sudo apt-get -y install ansible > /dev/null
fi

# Check if LXC is installed and if not, install it and its dependencies
if [[ ! `which lxc-info` ]]; then
    sudo apt-get -y install git python-all python-dev curl autoconf\
        g++ python2.7-dev software-properties-common ansible\
        lxc lxc-templates cloud-image-utils cloud-utils debootstrap cdebootstrap
fi

if [[ ! `sudo lxc-info -n base-container 2> /dev/null` ]]; then
    sudo lxc-create -n base-container -t ubuntu-cloud -- --release=trusty -S $SSH_KEY
fi

if [[ ! `sudo lxc-info -n haproxy 2> /dev/null` ]]; then
    sudo lxc-clone -o base-container -n haproxy -- -S $SSH_KEY
fi
if [[ `sudo lxc-info -s -H -n haproxy 2> /dev/null` != 'RUNNING' ]]; then
    sudo lxc-start -n haproxy -d
    echo "Started haproxy container..."
else
    echo "HAproxy container already running..."
fi

for i in 1 2 3; do
    if [[ ! `sudo lxc-info -n galera$i 2> /dev/null` ]]; then
        sudo lxc-clone -o base-container -n galera$i -- -S $SSH_KEY
    fi
done

for i in 1 2 3; do
    if [[ `sudo lxc-info -s -H -n galera$i 2> /dev/null` != 'RUNNING' ]]; then
        sudo lxc-start -n galera$i -d
        # Wait until an IP address has been assigned to the container
        NEXT_WAIT_TIME=0
        until [[ `sudo lxc-info -H -i -n galera$i` != '' || $NEXT_WAIT_TIME -eq 4 ]]; do
            sleep $(( NEXT_WAIT_TIME++ ))
        done
        echo "Started Galera cluster node container #$i..."
    else
        echo "Galera cluster node container #$i already running..."
    fi
done

HAPROXY_IP=`sudo lxc-info -i -H -n haproxy`
GALERA1_IP=`sudo lxc-info -i -H -n galera1`
GALERA2_IP=`sudo lxc-info -i -H -n galera2`
GALERA3_IP=`sudo lxc-info -i -H -n galera3`

cat > "$ANSIBLE_DIR/hosts" <<EOF
[galera]
$GALERA1_IP galera_bootstrap=1
$GALERA2_IP
$GALERA3_IP

[haproxy]
$HAPROXY_IP
EOF

sudo lxc-ls --fancy
NEXT_WAIT_TIME=0
until [[ `ssh-keyscan $HAPROXY_IP &> /dev/null` || $NEXT_WAIT_TIME -eq 4 ]]; do
    sleep $(( NEXT_WAIT_TIME++ ))
done
ssh-keyscan -t rsa $HAPROXY_IP 2> /dev/null >> $HOME/.ssh/known_hosts
echo "Added host keys for haproxy cluster node container..."

for i in 1 2 3; do
    # Wait until the host route is found and add the host key to the
    # list of local known hosts.
    THIS_CONTAINER_IP=`sudo lxc-info -i -H -n galera$i`
    NEXT_WAIT_TIME=0
    until [[ `ssh-keyscan $THIS_CONTAINER_IP &> /dev/null` || $NEXT_WAIT_TIME -eq 4 ]]; do
        sleep $(( NEXT_WAIT_TIME++ ))
    done
    ssh-keyscan -t rsa $THIS_CONTAINER_IP 2> /dev/null >> $HOME/.ssh/known_hosts
    echo "Added host keys for Galera cluster node container #$i..."
done
