## Start up Automate using docker

## Data Directories

The following directories must exist under `$DATA_MOUNT` and be owned by `$USER_ID`:

* postgresql
* rabbitmq
* elasticsearch
* maintenance
* workflow
* compliance
* nginx

## Arbitrary Random User/Group

If specifying an arbitrary and random uid/gid for the container processes,
you must bind mount a [passwd](passwd_example.md) and [group](group_example.md) file with those users into the container.
The example files provided should work just fine after replacing the `testuser` entry with your own.

```shell

# Configurable shell environment variables:
# DOCKER_ORIGIN - denotes the docker origin (dockerhub ID) or default to `chefserverofficial`
# VERSION -  the version identifier tag on the packages
# HOST_IP - the IP address of the docker host. 172.17.0.1 is commonly the docker0 interface which is fine
# ENTERPRISE - the name of the Automate enterprise to create
# ADMIN_PASSWORD - the initial password to set for the 'admin' user in the Automate UI
# AUTOMATE_TOKEN - the token for the Automate server data collector
# USER_ID - the user ID to use
# GROUP_ID - the group ID to use
# DATA_MOUNT - the mount point for the data

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
  --volume $(pwd)/passwd:/etc/passwd:ro \
  --volume $(pwd)/group:/etc/group:ro \
  --mount type=volume,src=postgresql_sup_state,dst=/hab/sup \
  --volume ${DATA_MOUNT:-/mnt/hab}/postgresql:/hab/svc \
  --cap-drop="NET_BIND_SERVICE" \
  --cap-drop="SETUID" \
  --cap-drop="SETGID" \
  --user="${USER_ID:-42}:${GROUP_ID:-42}" \
  --env="HAB_NON_ROOT=1" \
  --network=host \
  --detach=true \
  ${DOCKER_ORIGIN:-chefserverofficial}/postgresql:${VERSION:-latest} \

# rabbitmq

sudo docker volume create --driver local \
       --opt type=tmpfs \
       --opt device=tmpfs \
       --opt o=size=100m,uid=$USER_ID \
       rabbitmq_sup_state

sudo -E docker run --rm -it \
  --name="rabbitmq" \
  --env="HAB_RABBITMQ=[rabbitmq]
default_vhost = '/insights'
default_user = 'insights'
default_pass = 'chefrocks'
[rabbitmq.management]
enabled = true
" \
  --env="PATH=/bin" \
  --volume $(pwd)/passwd:/etc/passwd:ro \
  --volume $(pwd)/group:/etc/group:ro \
  --mount type=volume,src=rabbitmq_sup_state,dst=/hab/sup \
  --volume ${DATA_MOUNT:-/mnt/hab}/rabbitmq:/hab/svc \
  --cap-drop="NET_BIND_SERVICE" \
  --cap-drop="SETUID" \
  --cap-drop="SETGID" \
  --user="${USER_ID:-42}:${GROUP_ID:-42}" \
  --env="HAB_NON_ROOT=1" \
  --network=host \
  --detach=true \
  ${DOCKER_ORIGIN:-chefserverofficial}/rabbitmq:${VERSION:-latest} \
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
  --volume $(pwd)/passwd:/etc/passwd:ro \
  --volume $(pwd)/group:/etc/group:ro \
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

# logstash

sudo docker volume create --driver local \
       --opt type=tmpfs \
       --opt device=tmpfs \
       --opt o=size=100m,uid=$USER_ID \
       logstash_sup_state

sudo docker volume create --driver local \
       --opt type=tmpfs \
       --opt device=tmpfs \
       --opt o=size=100m,uid=$USER_ID \
       logstash_svc_state

sudo -E docker run --rm -it \
  --name="logstash" \
  --env="PATH=/bin" \
  --volume $(pwd)/passwd:/etc/passwd:ro \
  --volume $(pwd)/group:/etc/group:ro \
  --mount type=volume,src=logstash_sup_state,dst=/hab/sup \
  --mount type=volume,src=logstash_svc_state,dst=/hab/svc \
  --cap-drop="NET_BIND_SERVICE" \
  --cap-drop="SETUID" \
  --cap-drop="SETGID" \
  --user="${USER_ID:-42}:${GROUP_ID:-42}" \
  --env="HAB_NON_ROOT=1" \
  --network=host \
  --detach=true \
  ${DOCKER_ORIGIN:-chefserverofficial}/logstash:${VERSION:-latest} \
  --peer ${HOST_IP:-172.17.0.1} --bind elasticsearch:elasticsearch5.default --bind rabbitmq:rabbitmq.default --listen-gossip 0.0.0.0:9652 --listen-http 0.0.0.0:9662

# workflow-server

sudo docker volume create --driver local \
       --opt type=tmpfs \
       --opt device=tmpfs \
       --opt o=size=100m,uid=$USER_ID \
       workflow-server_sup_state

sudo -E docker run --rm -it \
  --name="workflow-server" \
  --env="HAB_WORKFLOW_SERVER=
enterprise = \"${ENTERPRISE:-default}\"
default_admin_password = \"${ADMIN_PASSWORD:-chefrocks}\"
[data_collector]
token = \"${AUTOMATE_TOKEN:-93a49a4f2482c64126f7b6015e6b0f30284287ee4054ff8807fb63d9cbd1c506}\"
" \
  --env="PATH=/bin" \
  --volume $(pwd)/passwd:/etc/passwd:ro \
  --volume $(pwd)/group:/etc/group:ro \
  --mount type=volume,src=workflow-server_sup_state,dst=/hab/sup \
  --volume ${DATA_MOUNT:-/mnt/hab}/workflow:/hab/svc \
  --volume ${DATA_MOUNT:-/mnt/hab}/maintenance:/var/opt/delivery/delivery/etc \
  --cap-drop="NET_BIND_SERVICE" \
  --cap-drop="SETUID" \
  --cap-drop="SETGID" \
  --user="${USER_ID:-42}:${GROUP_ID:-42}" \
  --env="HAB_NON_ROOT=1" \
  --network=host \
  --detach=true \
  ${DOCKER_ORIGIN:-chefserverofficial}/workflow-server:${VERSION:-latest} \
  --peer ${HOST_IP:-172.17.0.1} --bind database:postgresql.default --bind elasticsearch:elasticsearch5.default --bind rabbitmq:rabbitmq.default --listen-gossip 0.0.0.0:9653 --listen-http 0.0.0.0:9663

# notifications

sudo docker volume create --driver local \
       --opt type=tmpfs \
       --opt device=tmpfs \
       --opt o=size=100m,uid=$USER_ID \
       notifications_sup_state

sudo docker volume create --driver local \
       --opt type=tmpfs \
       --opt device=tmpfs \
       --opt o=size=100m,uid=$USER_ID \
       notifications_svc_state

sudo -E docker run --rm -it \
  --name="notifications" \
  --env="PATH=/bin" \
  --volume $(pwd)/passwd:/etc/passwd:ro \
  --volume $(pwd)/group:/etc/group:ro \
  --mount type=volume,src=notifications_sup_state,dst=/hab/sup \
  --mount type=volume,src=notifications_svc_state,dst=/hab/svc \
  --cap-drop="NET_BIND_SERVICE" \
  --cap-drop="SETUID" \
  --cap-drop="SETGID" \
  --user="${USER_ID:-42}:${GROUP_ID:-42}" \
  --env="HAB_NON_ROOT=1" \
  --network=host \
  --detach=true \
  ${DOCKER_ORIGIN:-chefserverofficial}/notifications:${VERSION:-latest} \
  --peer ${HOST_IP:-172.17.0.1} --bind elasticsearch:elasticsearch5.default --bind rabbitmq:rabbitmq.default --listen-gossip 0.0.0.0:9654 --listen-http 0.0.0.0:9664

# compliance

sudo docker volume create --driver local \
       --opt type=tmpfs \
       --opt device=tmpfs \
       --opt o=size=100m,uid=$USER_ID \
       compliance_sup_state

sudo -E docker run --rm -it \
  --name="compliance" \
  --env="PATH=/bin" \
  --volume $(pwd)/passwd:/etc/passwd:ro \
  --volume $(pwd)/group:/etc/group:ro \
  --mount type=volume,src=compliance_sup_state,dst=/hab/sup \
  --volume ${DATA_MOUNT:-/mnt/hab}/compliance:/hab/svc \
  --cap-drop="NET_BIND_SERVICE" \
  --cap-drop="SETUID" \
  --cap-drop="SETGID" \
  --user="${USER_ID:-42}:${GROUP_ID:-42}" \
  --env="HAB_NON_ROOT=1" \
  --network=host \
  --detach=true \
  ${DOCKER_ORIGIN:-chefserverofficial}/compliance:${VERSION:-latest} \
  --peer ${HOST_IP:-172.17.0.1} --bind elasticsearch:elasticsearch5.default --listen-gossip 0.0.0.0:9655 --listen-http 0.0.0.0:9665

# automate-nginx

sudo docker volume create --driver local \
       --opt type=tmpfs \
       --opt device=tmpfs \
       --opt o=size=100m,uid=$USER_ID \
       automate-nginx_sup_state

sudo -E docker run \
  --name="automate-nginx" \
  --env="HAB_AUTOMATE_NGINX: |
port = ${PILOT_HTTP_PORT:-8080}
ssl_port = ${PILOT_HTTPS_PORT:-8443}
" \
  --env="PATH=/bin" \
  --volume $(pwd)/passwd:/etc/passwd:ro \
  --volume $(pwd)/group:/etc/group:ro \
  --mount type=volume,src=automate-nginx_sup_state,dst=/hab/sup \
  --volume ${DATA_MOUNT:-/mnt/hab}/nginx:/hab/svc \
  --volume ${DATA_MOUNT:-/mnt/hab}/maintenance:/var/opt/delivery/delivery/etc \
  --cap-drop="NET_BIND_SERVICE" \
  --cap-drop="SETUID" \
  --cap-drop="SETGID" \
  --user="${USER_ID:-42}:${GROUP_ID:-42}" \
  --env="HAB_NON_ROOT=1" \
  --network=host \
  --detach=true \
  ${DOCKER_ORIGIN:-chefserverofficial}/automate-nginx:${VERSION:-latest} \
  --peer ${HOST_IP:-172.17.0.1} --bind compliance:compliance.default --bind elasticsearch:elasticsearch5.default --bind workflow:workflow-server.default --bind notifications:notifications.default --listen-gossip 0.0.0.0:9656 --listen-http 0.0.0.0:9666
```
