## Start up the Chef Server using docker

## Data Directories

The following directories must exist under `$DATA_MOUNT` and be owned by `$USER_ID`:

* postgresql
* elasticsearch
* nginx

## Arbitrary Random User/Group

If specifying an arbitrary and random uid/gid for the container processes,
you must bind mount a [passwd](passwd_example.md) and [group](group_example.md) file with those users into the container.
The example files provided should work just fine after replacing the `testuser` entry with your own.

In addition, you must provide volumes for `/hab/sup` and `/hab/svc` as described [here](https://www.habitat.sh/docs/best-practices/#running-habitat-linux-containers) and as seen below with the SERVICE_sup_state and SERVICE_svc_state volumes.


```bash

# Configurable shell environment variables:
# DOCKER_ORIGIN - denotes the docker origin (dockerhub ID) or default to `chefserverofficial`
# VERSION -  the version identifier tag on the packages
# HOST_IP - the IP address of the docker host. 172.17.0.1 is commonly the docker0 interface which is fine
# AUTOMATE_ENABLED - enable the Automate data collector (true or false)
# AUTOMATE_SERVER - the IP address or hostname of the Automate server
# AUTOMATE_TOKEN - the token for the Automate server data collector
# DATA_MOUNT - the mount point for the data
# USER_ID - the user ID to use (numeric)
# GROUP_ID - the group ID to use (numeric)


# Docker Services
#

# postgresql

sudo docker volume create --driver local \
       --opt type=tmpfs \
       --opt device=tmpfs \
       --opt o=size=100m,uid=$USER_ID \
       postgresql_sup_state

sudo -E docker run --rm -it \
  --name="postgresql" \
  --env="HAB_POSTGRESQL=[superuser]
name = 'hab'
password = 'chefrocks'
" \
  --env="PATH=/bin" \
  --volume ${DATA_MOUNT:-/mnt/hab}/passwd:/etc/passwd:ro \
  --volume ${DATA_MOUNT:-/mnt/hab}/group:/etc/group:ro \
  --mount type=volume,src=postgresql_sup_state,dst=/hab/sup \
  --volume ${DATA_MOUNT:-/mnt/hab}/postgresql:/hab/svc \
  --cap-drop="NET_BIND_SERVICE" \
  --cap-drop="SETUID" \
  --cap-drop="SETGID" \
  --user="${USER_ID:-42}:${GROUP_ID:-42}" \
  --env="HAB_NON_ROOT=1" \
  --network=host \
  --detach=true \
  ${DOCKER_ORIGIN:-chefserverofficial}/postgresql:${VERSION:-latest}

# chef-server-ctl

sudo docker volume create --driver local \
       --opt type=tmpfs \
       --opt device=tmpfs \
       --opt o=size=100m,uid=$USER_ID \
       chef-server-ctl_sup_state

sudo docker volume create --driver local \
       --opt type=tmpfs \
       --opt device=tmpfs \
       --opt o=size=100m,uid=$USER_ID \
       chef-server-ctl_svc_state

sudo -E docker run --rm -it \
  --name="chef-server-ctl" \
  --env="HAB_CHEF_SERVER_CTL=[chef_server_api]
ip = \"${HOST_IP:-172.17.0.1}\"
[secrets.data_collector]
token = \"${AUTOMATE_TOKEN:-93a49a4f2482c64126f7b6015e6b0f30284287ee4054ff8807fb63d9cbd1c506}\"
" \
  --env="PATH=/bin" \
  --mount type=volume,src=chef-server-ctl_sup_state,dst=/hab/sup \
  --mount type=volume,src=chef-server-ctl_svc_state,dst=/hab/svc \
  --cap-drop="NET_BIND_SERVICE" \
  --cap-drop="SETUID" \
  --cap-drop="SETGID" \
  --user="${USER_ID:-42}:${GROUP_ID:-42}" \
  --env="HAB_NON_ROOT=1" \
  --network=host \
  --detach=true \
  ${DOCKER_ORIGIN:-chefserverofficial}/chef-server-ctl:${VERSION:-latest} \
  --peer ${HOST_IP:-172.17.0.1} --listen-gossip 0.0.0.0:9650 --listen-http 0.0.0.0:9660

# elasticsearch

sudo docker volume create --driver local \
       --opt type=tmpfs \
       --opt device=tmpfs \
       --opt o=size=100m,uid=$USER_ID \
       elasticsearch_sup_state

sudo -E docker run --rm -it \
  --name="elasticsearch" \
  --env="PATH=/bin" \
  --mount type=volume,src=elasticsearch_sup_state,dst=/hab/sup \
  --volume ${DATA_MOUNT:-/mnt/hab}/elasticsearch:/hab/svc \
  --cap-drop="NET_BIND_SERVICE" \
  --cap-drop="SETUID" \
  --cap-drop="SETGID" \
  --user="${USER_ID:-42}:${GROUP_ID:-42}" \
  --env="HAB_NON_ROOT=1" \
  --network=host \
  --ulimit nofile=65536:65536 \
  --detach=true \
  ${DOCKER_ORIGIN:-chefserverofficial}/elasticsearch5:${VERSION:-latest} \
  --peer ${HOST_IP:-172.17.0.1} --listen-gossip 0.0.0.0:9651 --listen-http 0.0.0.0:9661

# oc_id

sudo docker volume create --driver local \
       --opt type=tmpfs \
       --opt device=tmpfs \
       --opt o=size=100m,uid=$USER_ID \
       oc_id_sup_state

sudo docker volume create --driver local \
       --opt type=tmpfs \
       --opt device=tmpfs \
       --opt o=size=100m,uid=$USER_ID \
       oc_id_svc_state

sudo -E docker run --rm -it \
  --name="oc_id" \
  --env="PATH=/bin" \
  --mount type=volume,src=oc_id_sup_state,dst=/hab/sup \
  --mount type=volume,src=oc_id_svc_state,dst=/hab/svc \
  --cap-drop="NET_BIND_SERVICE" \
  --cap-drop="SETUID" \
  --cap-drop="SETGID" \
  --user="${USER_ID:-42}:${GROUP_ID:-42}" \
  --env="HAB_NON_ROOT=1" \
  --network=host \
  --detach=true \
  ${DOCKER_ORIGIN:-chefserverofficial}/oc_id:${VERSION:-latest} \
  --peer ${HOST_IP:-172.17.0.1} --bind database:postgresql.default --bind chef-server-ctl:chef-server-ctl.default --listen-gossip 0.0.0.0:9652 --listen-http 0.0.0.0:9662

# bookshelf

sudo docker volume create --driver local \
       --opt type=tmpfs \
       --opt device=tmpfs \
       --opt o=size=100m,uid=$USER_ID \
       bookshelf_sup_state

sudo docker volume create --driver local \
       --opt type=tmpfs \
       --opt device=tmpfs \
       --opt o=size=100m,uid=$USER_ID \
       bookshelf_svc_state

sudo -E docker run --rm -it \
  --name="bookshelf" \
  --env="PATH=/bin" \
  --mount type=volume,src=bookshelf_sup_state,dst=/hab/sup \
  --mount type=volume,src=bookshelf_svc_state,dst=/hab/svc \
  --cap-drop="NET_BIND_SERVICE" \
  --cap-drop="SETUID" \
  --cap-drop="SETGID" \
  --user="${USER_ID:-42}:${GROUP_ID:-42}" \
  --env="HAB_NON_ROOT=1" \
  --network=host \
  --detach=true \
  ${DOCKER_ORIGIN:-chefserverofficial}/bookshelf:${VERSION:-latest} \
  --peer ${HOST_IP:-172.17.0.1} --bind database:postgresql.default --bind chef-server-ctl:chef-server-ctl.default --listen-gossip 0.0.0.0:9653 --listen-http 0.0.0.0:9663

# oc_bifrost

sudo docker volume create --driver local \
       --opt type=tmpfs \
       --opt device=tmpfs \
       --opt o=size=100m,uid=$USER_ID \
       oc_bifrost_sup_state

sudo docker volume create --driver local \
       --opt type=tmpfs \
       --opt device=tmpfs \
       --opt o=size=100m,uid=$USER_ID \
       oc_bifrost_svc_state

sudo -E docker run --rm -it \
  --name="oc_bifrost" \
  --env="PATH=/bin" \
  --mount type=volume,src=oc_bifrost_sup_state,dst=/hab/sup \
  --mount type=volume,src=oc_bifrost_svc_state,dst=/hab/svc \
  --cap-drop="NET_BIND_SERVICE" \
  --cap-drop="SETUID" \
  --cap-drop="SETGID" \
  --user="${USER_ID:-42}:${GROUP_ID:-42}" \
  --env="HAB_NON_ROOT=1" \
  --network=host \
  --detach=true \
  ${DOCKER_ORIGIN:-chefserverofficial}/oc_bifrost:${VERSION:-latest} \
  --peer ${HOST_IP:-172.17.0.1} --bind database:postgresql.default --bind chef-server-ctl:chef-server-ctl.default --listen-gossip 0.0.0.0:9654 --listen-http 0.0.0.0:9664

# oc_erchef

sudo docker volume create --driver local \
       --opt type=tmpfs \
       --opt device=tmpfs \
       --opt o=size=100m,uid=$USER_ID \
       oc_erchef_sup_state

sudo docker volume create --driver local \
       --opt type=tmpfs \
       --opt device=tmpfs \
       --opt o=size=100m,uid=$USER_ID \
       oc_erchef_svc_state

sudo -E docker run --rm -it \
  --name="oc_erchef" \
  --env="HAB_OC_ERCHEF=[data_collector]
enabled = ${AUTOMATE_ENABLED:-false}
server = \"${AUTOMATE_SERVER:-localhost}\"
port = 443
[chef_authn]
keygen_cache_workers = 2
keygen_cache_size = 10
keygen_start_size = 0
keygen_timeout = 20000
" \
  --env="PATH=/bin" \
  --mount type=volume,src=oc_erchef_sup_state,dst=/hab/sup \
  --mount type=volume,src=oc_erchef_svc_state,dst=/hab/svc \
  --cap-drop="NET_BIND_SERVICE" \
  --cap-drop="SETUID" \
  --cap-drop="SETGID" \
  --user="${USER_ID:-42}:${GROUP_ID:-42}" \
  --env="HAB_NON_ROOT=1" \
  --network=host \
  --detach=true \
  ${DOCKER_ORIGIN:-chefserverofficial}/oc_erchef:${VERSION:-latest} \
  --peer ${HOST_IP:-172.17.0.1} --bind bookshelf:bookshelf.default --bind oc_bifrost:oc_bifrost.default --bind database:postgresql.default --bind elasticsearch:elasticsearch5.default --bind chef-server-ctl:chef-server-ctl.default --listen-gossip 0.0.0.0:9655 --listen-http 0.0.0.0:9665

# chef-server-nginx

sudo docker volume create --driver local \
       --opt type=tmpfs \
       --opt device=tmpfs \
       --opt o=size=100m,uid=$USER_ID \
       chef-server-nginx_sup_state

sudo -E docker run --rm -it \
  --name="chef-server-nginx" \
  --env="PATH=/bin" \
  --mount type=volume,src=chef-server-nginx_sup_state,dst=/hab/sup \
  --volume ${DATA_MOUNT:-/mnt/hab}/nginx:/hab/svc \
  --cap-drop="NET_BIND_SERVICE" \
  --cap-drop="SETUID" \
  --cap-drop="SETGID" \
  --user="${USER_ID:-42}:${GROUP_ID:-42}" \
  --env="HAB_NON_ROOT=1" \
  --network=host \
  --detach=true \
  ${DOCKER_ORIGIN:-chefserverofficial}/chef-server-nginx:${VERSION:-latest} \
  --peer ${HOST_IP:-172.17.0.1} --bind oc_erchef:oc_erchef.default --bind oc_bifrost:oc_bifrost.default --bind oc_id:oc_id.default --bind bookshelf:bookshelf.default --bind elasticsearch:elasticsearch5.default --bind chef-server-ctl:chef-server-ctl.default --listen-gossip 0.0.0.0:9656 --listen-http 0.0.0.0:9666
