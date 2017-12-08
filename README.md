# dockerized-chef-services
Docker compose definitions for Chef Server and Automate 1.x

# 2 Standalones configuration

The [2 Standalones configuration](https://github.com/chef-customers/dockerized-chef-services/tree/master/2-standalones) is closest to the default topology for Chef Automate, where a standalone Chef Server is paired with a standalone Chef Automate server.

![2 standalones diagram](https://www.lucidchart.com/publicSegments/view/4f01dc86-c34a-49a9-b619-f3d1056e7a41/image.png)

## How it works

* All of the Chef Server and Chef Automate services have been packaged as Habitat `.hart` files here: [https://bldr.habitat.sh/#/pkgs/chef-server]
 * and exported to docker containers here:  [https://hub.docker.com/r/chefserverofficial/]
* 2 `docker-compose` configuration files have been created which pull the docker containers and run them using Host mode networking
* Each host forms its own non-permanent Habitat gossip ring, sharing service discovery data intra-host only
* Environment variables are used to configure settings from the default

## Deploying it

### Using AWS and Terraform

Customize the `main.tf` [Terraform](terraform.io) configuration file and deploy with `terraform apply`

### Manually

1. Provision 2 hosts that are running a modern Linux OS (RHEL 7 or Ubuntu 16.04) as well as recent versions of Docker and docker-compose
1. Attach SAN (block) storage to each host for storing persistent data
1. copy the `automate.yml` file to the first host, and run:
```
export ENTERPRISE=mycompany
export ADMIN_PASSWORD=SuperSecurePassword42
export AUTOMATE_TOKEN=93a49a4f2482c64126f7b6015e6b0f30284287ee4054ff8807fb63d9cbd1c506
sudo -E docker-compose -f automate.yml up -d
```
1. copy the `chef-server.yml` file to the second host and run:
```
export AUTOMATE_ENABLED=true
export AUTOMATE_SERVER=automate-server-hostname-or-ip.mycompany.com
export AUTOMATE_TOKEN=93a49a4f2482c64126f7b6015e6b0f30284287ee4054ff8807fb63d9cbd1c506
sudo -E docker-compose -f chef-server.yml up -d
```
