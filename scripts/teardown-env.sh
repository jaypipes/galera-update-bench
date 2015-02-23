#!/usr/bin/env bash
# NOTE(jaypipes): This only tested on Ubuntu 14.04.

set -e

echo "Stopping Galera containers..."

sudo lxc-stop -n galera1
sudo lxc-stop -n galera2
sudo lxc-stop -n galera3

echo "Destroying Galera containers..."

sudo lxc-destroy -n galera1
sudo lxc-destroy -n galera2
sudo lxc-destroy -n galera3

echo "Removing any old LXC container known_hosts entries..."

sed -i "/^10\.0\.3/d" $HOME/.ssh/known_hosts || /bin/true
