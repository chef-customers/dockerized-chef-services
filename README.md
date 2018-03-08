# dockerized-chef-services
Docker definitions for Chef Server and Automate 1.x

# 2 Standalones configuration

The [2 Standalones configuration](https://github.com/chef-customers/dockerized-chef-services/tree/master/2-standalones) is closest to the default topology for Chef Automate, where a standalone Chef Server is paired with a standalone Chef Automate server.

![2 standalones diagram](https://www.lucidchart.com/publicSegments/view/4f01dc86-c34a-49a9-b619-f3d1056e7a41/image.png)

## How it works

* All of the Chef Server and Chef Automate services have been packaged as Habitat `.hart` files here: [https://bldr.habitat.sh/#/pkgs/chef-server]
* and exported to docker containers here:  [https://hub.docker.com/r/chefserverofficial/]
* These containers support running under a random, arbitrary user and/or group id.
* Launch containers via `docker-compose` or `docker run ...`  Compose files have been created which pull the docker containers and run them using Host mode networking. Alternatively, [docker run Chef Server](https://github.com/chef-customers/dockerized-chef-services/tree/master/docker_run_chef_server.md) and [docker run Automate](https://github.com/chef-customers/dockerized-chef-services/tree/master/docker_run_automate.md) files demonstrate how to launch via `docker run ...` commands.
* Each host forms its own non-permanent Habitat gossip ring, sharing service discovery data intra-host only
* Environment variables are used to configure settings from the default

## Deploying it

### Using AWS and Terraform

Customize the `main.tf` [Terraform](terraform.io) configuration file and deploy with `terraform apply`

### Manually

1. Provision 2 hosts that are running a modern Linux OS (RHEL 7 or Ubuntu 16.04) as well as recent versions of Docker and optionally docker-compose
2. Attach SAN (block) storage to each host for storing persistent data
3. Read [Deployment Notes](https://github.com/chef-customers/dockerized-chef-services#deployment-notes)

### Data Directories

Each Host must have directories created under `$DATA_MOUNT` and be owned by `$USER_ID`:

For Automate 1.x:

* postgresql
* rabbitmq
* elasticsearch
* maintenance
* workflow
* compliance
* nginx

For Chef Server:

* postgresql
* elasticsearch
* nginx

The directories above should be created prior and are expected to be stable to provide persistent storage to the containers.

### Arbitrary Random User/Group ids

If specifying an arbitrary and random uid/gid for the container processes,
you must bind mount a [passwd](passwd_example.md) and [group](group_example.md) file with those users into the container.
The example files provided should work just fine after replacing the `testuser` entry with your own.

#### Docker Compose
1. copy the `automate.yml` file to the first host, and run:
```
export ENTERPRISE=mycompany
export ADMIN_PASSWORD=SuperSecurePassword42
export AUTOMATE_TOKEN=93a49a4f2482c64126f7b6015e6b0f30284287ee4054ff8807fb63d9cbd1c506
export USER_ID=9999
export GROUP_ID=8888
export DATA_MOUNT=/path/to/persistent/storage/directory
sudo -E docker-compose -f automate.yml up -d
```
2. copy the `chef-server.yml` file to the second host and run:
```
export AUTOMATE_ENABLED=true
export AUTOMATE_SERVER=automate-server-hostname-or-ip.mycompany.com
export AUTOMATE_TOKEN=93a49a4f2482c64126f7b6015e6b0f30284287ee4054ff8807fb63d9cbd1c506
export USER_ID=9999
export GROUP_ID=8888
export DATA_MOUNT=/path/to/persistent/storage/directory
sudo -E docker-compose -f chef-server.yml up -d
```

### Docker Run
1. copy the bash script contents of [docker_run_automate.md](docker_run_automate.md) file to the first host, rename it to .sh, and run:
```
export ENTERPRISE=mycompany
export ADMIN_PASSWORD=SuperSecurePassword42
export AUTOMATE_TOKEN=93a49a4f2482c64126f7b6015e6b0f30284287ee4054ff8807fb63d9cbd1c506
export USER_ID=9999
export GROUP_ID=8888
export DATA_MOUNT=/path/to/persistent/storage/directory
./docker_run_automate.sh
```
2. copy the bash script contents of [docker_run_chef_server.md](docker_run_chef_server.md) file to the second host, rename it to .sh, and run:
```
export AUTOMATE_ENABLED=true
export AUTOMATE_SERVER=automate-server-hostname-or-ip.mycompany.com
export AUTOMATE_TOKEN=93a49a4f2482c64126f7b6015e6b0f30284287ee4054ff8807fb63d9cbd1c506
export USER_ID=9999
export GROUP_ID=8888
export DATA_MOUNT=/path/to/persistent/storage/directory
./docker_run_chef_server.sh
```

## Deployment notes

Some environments may require the following, particularly if Elasticsearch refuses to start:

```
sudo cat > /etc/sysctl.d/00-chef.conf <<EOF
vm.swappiness=10
vm.max_map_count=262144
vm.dirty_ratio=20
vm.dirty_background_ratio=30
vm.dirty_expire_centisecs=30000
EOF
sudo sysctl -p /etc/sysctl.d/00-chef.conf

sudo cat > /etc/security/limits.d/20-nproc.conf<<EOF
*   soft  nproc     65536
*   hard  nproc     65536
*   soft  nofile    1048576
*   hard  nofile    1048576
EOF
```

Ensuring that locale is UTF-8 is necessary if not already set:

```
export LC_ALL=en_US.UTF-8
```

For the non-root images, all the services run on non-privileged ports. To enable seamless external access
to TCP ports 80 and 443 the following iptables rules must be applied.
Alternatively, use a Load Balancer.

If not using a LB, on the Chef Server Host run:

```
sudo iptables -A PREROUTING -t nat -p tcp --dport 80 -j REDIRECT --to-port 8080
sudo iptables -A PREROUTING -t nat -p tcp --dport 443 -j REDIRECT --to-port 8443
sudo iptables -t nat -A OUTPUT -o lo -p tcp --dport 80 -j REDIRECT --to-port 8080
sudo iptables -t nat -A OUTPUT -o lo -p tcp --dport 443 -j REDIRECT --to-port 8443
```

And on the Automate Host:

```
sudo iptables -A PREROUTING -t nat -p tcp --dport 80 -j REDIRECT --to-port 8080
sudo iptables -A PREROUTING -t nat -p tcp --dport 443 -j REDIRECT --to-port 8443
```

# Operating it

## Chef Server administrative functions

Run the functional test suite to ensure Chef server is working:

docker-compose:

```
docker-compose -f chef-server.yml exec chef-server-ctl chef-server-test
```

docker run:

```
docker exec -it <container id of chef-server-ctl> chef-server-test
```

Add users, orgs, etc to the Chef server

docker-compose:

```
docker-compose -f chef-server.yml exec chef-server-ctl chef-server-ctl (subcommands)
```

docker run:

```
docker exec -it <container id of chef-server-ctl> chef-server-ctl (subcommands)
```

## Logging
All container logs are directed to STDOUT. You should employ a Docker logging mechanism to ensure those logs are captured and aggregated in a central location. Being able to provide full logs from all containers is necessary in order to recieve support.

To view the status of any container:

docker-compose:

```
docker-compose logs <container name>
```

docker run:

```
docker logs <container id>
```

An easy way to check on the health of Chef Server and Automate is to look for the health checks from `oc_erchef` and `workflow-server` containers accordingly. They will look like:

```
oc_erchef.default hook[health_check]:(HK): {"status":"pong","upstreams":{"chef_elasticsearch":"pong","chef_sql":"pong","oc_chef_authz":"pong"},
"keygen":{"keys":10,"max":10,"max_workers":10,"cur_max_workers":10,"inflight":0,"avail_workers":10,"start_size":0},"indexing":{"mode":"batch"}}
```

```
workflow-server.default hook[health_check]:(HK): {"status":"pong","configuration_mode":"standalone","fips_mode":"false","upstreams":
[{"postgres":{"status":"pong"},"lsyncd":{"status":"not_running"},"elasticsearch":{"status":"pong","cluster_name":"elasticsearch","status":
"yellow","timed_out":false,"number_of_nodes":1,"number_of_data_nodes":1,"active_primary_shards":20,"active_shards":20,"relocating_shards":0,
"initializing_shards":0,"unassigned_shards":20,"delayed_unassigned_shards":0,"number_of_pending_tasks":0,"number_of_in_flight_fetch":0,
"task_max_waiting_in_queue_millis":0,"active_shards_percent_as_number":50.0},"rabbitmq":{"status":"pong","vhost_aliveness":{"status":
"pong"},"node_health":{"status":"pong"}}}]}
```
