Usage
-----

This repository sets up 3 LXC containers containing a Galera cluster, a
container running HAProxy, and can run a set of benchmarks against the Galera
cluster.

To set up the LXC containers, run the create-env.sh script after pulling
this repository:

```
git clone git@github.com:jaypipes/galera-update-bench
cd galera-update-bench
./scripts/create-env.sh
```

Output of the `create-env.sh` script should look something like the following:

```
jaypipes@minty:~/repos/galera-update-bench$ ./scripts/create-env.sh 
[sudo] password for jaypipes: 
Started haproxy container...
Started Galera cluster node container #1...
Started Galera cluster node container #2...
Started Galera cluster node container #3...
NAME            STATE    IPV4        IPV6  GROUPS  AUTOSTART  
------------------------------------------------------------
base-container  STOPPED  -           -     -       NO         
galera1         RUNNING  10.0.3.245  -     -       NO         
galera2         RUNNING  10.0.3.19   -     -       NO         
galera3         RUNNING  10.0.3.101  -     -       NO         
haproxy         RUNNING  10.0.3.74   -     -       NO         
Added host keys for haproxy cluster node container...
Added host keys for Galera cluster node container #1...
Added host keys for Galera cluster node container #2...
Added host keys for Galera cluster node container #3...
```

Note that the `create-env.sh` script automatically adds the host keys
for each of the LXC containers to your SSH `known_hosts` file, so to
log into one of the Galera LXC nodes, simply SSH to it as the ubuntu user:

```
jaypipes@spearmint$ ssh ubuntu@10.0.3.245
Welcome to Ubuntu 14.04.1 LTS (GNU/Linux 3.13.0-37-generic x86_64)

 * Documentation:  https://help.ubuntu.com/

  System information as of Sun Feb 22 20:30:03 EST 2015

  System load:  0.33             Processes:           26
  Usage of /:   2.0% of 1.61TB   Users logged in:     0
  Memory usage: 35%              IP address for eth0: 10.0.3.245
  Swap usage:   0%

  Graph this data and manage this system at:
    https://landscape.canonical.com/

  Get cloud support with Ubuntu Advantage Cloud Guest:
    http://www.ubuntu.com/business/services/cloud


Last login: Sun Feb 22 20:30:03 2015 from 10.0.3.1
```

Once the LXC containers are ready, you can install the Galera and HAProxy
software within the containers using the Ansible playbooks:

```
pushd ansible
ansible-playbook -i hosts site.yml
popd
```

You may execute commands, including checking for the status of
the Galera cluster, using `lxc-attach -n <CONTAINER_NAME> -- <COMMAND>`:

```
jaypipes@spearmint$ sudo lxc-attach -n galera1 -- mysql -uroot -e "show global status like 'wsrep_cluster%'" 
+--------------------------+--------------------------------------+
| Variable_name            | Value                                |
+--------------------------+--------------------------------------+
| wsrep_cluster_conf_id    | 2                                    |
| wsrep_cluster_size       | 3                                    |
| wsrep_cluster_state_uuid | 471b8e63-bafb-11e4-a9c0-d67ae6216c67 |
| wsrep_cluster_status     | Primary                              |
+--------------------------+--------------------------------------+
```

To run the benchmark scripts, execute the `scripts/benchmark.sh` script:

```

```
