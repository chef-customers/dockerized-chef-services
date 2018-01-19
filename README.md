# dockerized-chef-services
Docker definitions for Chef Server and Automate 1.x

# 2 Standalones configuration

The [2 Standalones configuration](https://github.com/chef-customers/dockerized-chef-services/tree/master/2-standalones) is closest to the default topology for Chef Automate, where a standalone Chef Server is paired with a standalone Chef Automate server.

![2 standalones diagram](https://www.lucidchart.com/publicSegments/view/4f01dc86-c34a-49a9-b619-f3d1056e7a41/image.png)

## How it works

* All of the Chef Server and Chef Automate services have been packaged as Habitat `.hart` files here: [https://bldr.habitat.sh/#/pkgs/chef-server]
 * and exported to docker containers here:  [https://hub.docker.com/r/chefserverofficial/]
* Launch containers via `docker-compose` or `docker run ...`  Compose files have been created which pull the docker containers and run them using Host mode networking. Alternatively, [docker run Chef Server](https://github.com/chef-customers/dockerized-chef-services/tree/master/docker_run_chef_server.md) and [docker run Automate](https://github.com/chef-customers/dockerized-chef-services/tree/master/docker_run_automate.md) files demonstrate how to launch via `docker run ...` commands.
* Each host forms its own non-permanent Habitat gossip ring, sharing service discovery data intra-host only
* Environment variables are used to configure settings from the default

## Deploying it

### Using AWS and Terraform

Customize the `main.tf` [Terraform](terraform.io) configuration file and deploy with `terraform apply`

### Manually


1. Provision 2 hosts that are running a modern Linux OS (RHEL 7 or Ubuntu 16.04) as well as recent versions of Docker and optionally docker-compose
2. Attach SAN (block) storage to each host for storing persistent data

#### Docker Compose
1. copy the `automate.yml` file to the first host, and run:
```
export ENTERPRISE=mycompany
export ADMIN_PASSWORD=SuperSecurePassword42
export AUTOMATE_TOKEN=93a49a4f2482c64126f7b6015e6b0f30284287ee4054ff8807fb63d9cbd1c506
sudo -E docker-compose -f automate.yml up -d
```
2. copy the `chef-server.yml` file to the second host and run:
```
export AUTOMATE_ENABLED=true
export AUTOMATE_SERVER=automate-server-hostname-or-ip.mycompany.com
export AUTOMATE_TOKEN=93a49a4f2482c64126f7b6015e6b0f30284287ee4054ff8807fb63d9cbd1c506
sudo -E docker-compose -f chef-server.yml up -d
```

### Docker Run
1. copy the bash script contents of `docker_run_automate.md` file to the first host, rename it to .sh, and run:
```
export ENTERPRISE=mycompany
export ADMIN_PASSWORD=SuperSecurePassword42
export AUTOMATE_TOKEN=93a49a4f2482c64126f7b6015e6b0f30284287ee4054ff8807fb63d9cbd1c506
./docker_run_automate.sh
```
2. copy the bash script contents of `docker_run_chef_server.md` file to the second host, rename it to .sh, and run:
```
export AUTOMATE_ENABLED=true
export AUTOMATE_SERVER=automate-server-hostname-or-ip.mycompany.com
export AUTOMATE_TOKEN=93a49a4f2482c64126f7b6015e6b0f30284287ee4054ff8807fb63d9cbd1c506
./docker_run_chef_server.sh
```

## Deployment notes

some environments may require the following, particularly if Elasticsearch refuses to start:
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

export LC_ALL=en_US.UTF-8
```


# Operating it

## Chef Server administrative functions

Run the functional test suite to ensure Chef server is working:
```
docker-compose -f chef-server.yml exec chef-server-ctl bash /bin/chef-server-test
```

Add users, orgs, etc to the Chef server
```
docker-compose -f chef-server.yml exec chef-server-ctl bash /bin/chef-server-ctl
```
