#!/usr/bin/env bash
# NOTE(jaypipes): This tested on Ubuntu 14.04 and 14.10.

set -e

echo "Stopping containers..."

sudo lxc-stop -n galera1
sudo lxc-stop -n galera2
sudo lxc-stop -n galera3
sudo lxc-stop -n haproxy

echo "Destroying containers..."

sudo lxc-destroy -n galera1
sudo lxc-destroy -n galera2
sudo lxc-destroy -n galera3
sudo lxc-destroy -n haproxy

echo "Removing any old LXC container known_hosts entries..."

sed -i "/^10\.0\.3/d" $HOME/.ssh/known_hosts || /bin/true
