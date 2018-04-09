# dockerized-chef-services
Docker definitions for Chef Server and Automate 1.x

![Architecture Diagram](https://www.lucidchart.com/publicSegments/view/4f01dc86-c34a-49a9-b619-f3d1056e7a41/image.png)

## How it works

* All of the Chef Server and Chef Automate services have been packaged as Habitat `.hart` files
* The hab packages have been exported to docker containers and published to docker hub
* These containers support running under a random, arbitrary effective user and/or group id
* Launch containers via the included [Chef Server](https://github.com/chef-customers/dockerized-chef-services/tree/master/terraform/chef-server.sh) or [Automate Server](https://github.com/chef-customers/dockerized-chef-services/tree/master/terraform/automate-server.sh) scripts, or alternatively via `docker run ..`
* Each host forms its own non-permanent Habitat gossip ring, sharing service discovery data intra-host only
* Environment variables are used to configure settings from the default

## Deploying it

### Using AWS and Terraform

Customize the `terraform.tfvars.example` [Terraform](terraform.io) configuration file, rename it to `terraform.tfvars` and deploy with `terraform apply`

```bash
git clone https://github.com/chef-customers/dockerized-chef-services.git
cd dockerized-chef-services/terraform
cp terraform.tfvars.example terraform.tfvars
vi terraform.tfvars # change anything that needs customization
terraform init
terraform apply
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

```
docker exec -it chef-server-ctl chef-server-test
```

Add users, orgs, etc to the Chef server

docker run:

```
docker exec -it chef-server-ctl chef-server-ctl (subcommands)
```

## Logging
All container logs are directed to STDOUT. You should employ a Docker logging mechanism to ensure those logs are captured and aggregated in a central location. Being able to provide full logs from all containers is necessary in order to recieve support.

To view the status of any container:

docker run:

```
docker logs <container name or id>
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
