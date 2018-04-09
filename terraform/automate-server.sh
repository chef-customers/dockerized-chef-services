#!/bin/bash

# Configurable shell environment variables:
# AUTOMATE_DOCKER_ORIGIN - denotes the docker origin (dockerhub ID) or default to `chefserverofficial`
# AUTOMATE_VERSION - the version identifier tag on the packages
# HOST_IP - the IP address of the docker host. 172.17.0.1 is commonly the docker0 interface which is fine
# ENTERPRISE - the name of the Automate enterprise to create
# ADMIN_PASSWORD - the initial password to set for the 'admin' user in the Automate UI
# AUTOMATE_TOKEN - the token for the Automate server data collector
# USER_ID - the user ID to use
# GROUP_ID - the group ID to use
# DATA_MOUNT - the mount point for the data


if [ -f "env.sh" ]; then
 echo "Setting ENVIRONMENT variables"
 . ./env.sh
fi

for svc in postgresql rabbitmq elasticsearch logstash workflow-server notifications compliance automate-nginx maintenance; do
  # NOTE: If launching all the services at once from a down state, then clearing out `/hab/sup` ensures
  # a clean slate so that the ring can be established. This guarantees ring recovery when things go sideways..
  # Do not do this for (re-)starting individual services as it will lead to exclusion of the service from the ring.
  sudo rm -rf "${DATA_MOUNT:-/mnt/hab}/${svc}_sup"

  dirs="${DATA_MOUNT:-/mnt/hab}/${svc}_svc ${DATA_MOUNT:-/mnt/hab}/${svc}_sup"
  echo "Ensuring $svc directories exist ($dirs)"
  sudo mkdir -p $dirs
  sudo chown -R $USER_ID:$GROUP_ID $dirs
done

# postgresql

# NOTE: The Supervisor won't start if /hab/sup/default/LOCK exists
# if it exists, you'll need to account for its removal in order to start the services
echo "Removing any stale LOCK files for postgresql"
sudo rm -f "${DATA_MOUNT:-/mnt/hab}/postgresql_sup/default/LOCK"
sudo -E docker run --rm -it \
  --name="postgresql" \
  --env="HAB_POSTGRESQL=[superuser]
name = 'hab'
password = 'chefrocks'
" \
  --env="PATH=/bin" \
  --volume ${DATA_MOUNT:-/mnt/hab}/passwd:/etc/passwd:ro \
  --volume ${DATA_MOUNT:-/mnt/hab}/group:/etc/group:ro \
  --volume ${DATA_MOUNT:-/mnt/hab}/postgresql_svc:/hab/svc \
  --volume ${DATA_MOUNT:-/mnt/hab}/postgresql_sup:/hab/sup \
  --cap-drop="NET_BIND_SERVICE" \
  --cap-drop="SETUID" \
  --cap-drop="SETGID" \
  --user="${USER_ID:-42}:${GROUP_ID:-42}" \
  --network=host \
  --detach=true \
  ${AUTOMATE_DOCKER_ORIGIN:-chefserverofficial}/postgresql:${AUTOMATE_VERSION:-latest}

# rabbitmq

# NOTE: The Supervisor won't start if /hab/sup/default/LOCK exists
# if it exists, you'll need to account for its removal in order to start the services
echo "Removing any stale LOCK files for rabbitmq"
sudo rm -f "${DATA_MOUNT:-/mnt/hab}/rabbitmq_sup/default/LOCK"
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
  --volume ${DATA_MOUNT:-/mnt/hab}/passwd:/etc/passwd:ro \
  --volume ${DATA_MOUNT:-/mnt/hab}/group:/etc/group:ro \
  --volume ${DATA_MOUNT:-/mnt/hab}/rabbitmq_svc:/hab/svc \
  --volume ${DATA_MOUNT:-/mnt/hab}/rabbitmq_sup:/hab/sup \
  --cap-drop="NET_BIND_SERVICE" \
  --cap-drop="SETUID" \
  --cap-drop="SETGID" \
  --user="${USER_ID:-42}:${GROUP_ID:-42}" \
  --network=host \
  --detach=true \
  ${AUTOMATE_DOCKER_ORIGIN:-chefserverofficial}/rabbitmq:${AUTOMATE_VERSION:-latest} \
  --peer ${HOST_IP:-172.17.0.1} --listen-gossip 0.0.0.0:9650 --listen-http 0.0.0.0:9660

# elasticsearch

# NOTE: The Supervisor won't start if /hab/sup/default/LOCK exists
# if it exists, you'll need to account for its removal in order to start the services
echo "Removing any stale LOCK files for elasticsearch"
sudo rm -f "${DATA_MOUNT:-/mnt/hab}/elasticsearch_sup/default/LOCK"
sudo -E docker run --rm -it \
  --name="elasticsearch" \
  --env="PATH=/bin" \
  --volume ${DATA_MOUNT:-/mnt/hab}/passwd:/etc/passwd:ro \
  --volume ${DATA_MOUNT:-/mnt/hab}/group:/etc/group:ro \
  --volume ${DATA_MOUNT:-/mnt/hab}/elasticsearch_svc:/hab/svc \
  --volume ${DATA_MOUNT:-/mnt/hab}/elasticsearch_sup:/hab/sup \
  --cap-drop="NET_BIND_SERVICE" \
  --cap-drop="SETUID" \
  --cap-drop="SETGID" \
  --user="${USER_ID:-42}:${GROUP_ID:-42}" \
  --network=host \
  --ulimit nofile=65536:65536 \
  --detach=true \
  ${AUTOMATE_DOCKER_ORIGIN:-chefserverofficial}/elasticsearch5:${AUTOMATE_VERSION:-latest} \
  --peer ${HOST_IP:-172.17.0.1} --listen-gossip 0.0.0.0:9651 --listen-http 0.0.0.0:9661

# logstash

# NOTE: The Supervisor won't start if /hab/sup/default/LOCK exists
# if it exists, you'll need to account for its removal in order to start the services
echo "Removing any stale LOCK files for logstash"
sudo rm -f "${DATA_MOUNT:-/mnt/hab}/logstash_sup/default/LOCK"
sudo -E docker run --rm -it \
  --name="logstash" \
  --env="PATH=/bin" \
  --volume ${DATA_MOUNT:-/mnt/hab}/passwd:/etc/passwd:ro \
  --volume ${DATA_MOUNT:-/mnt/hab}/group:/etc/group:ro \
  --volume ${DATA_MOUNT:-/mnt/hab}/logstash_svc:/hab/svc \
  --volume ${DATA_MOUNT:-/mnt/hab}/logstash_sup:/hab/sup \
  --cap-drop="NET_BIND_SERVICE" \
  --cap-drop="SETUID" \
  --cap-drop="SETGID" \
  --user="${USER_ID:-42}:${GROUP_ID:-42}" \
  --network=host \
  --detach=true \
  ${AUTOMATE_DOCKER_ORIGIN:-chefserverofficial}/logstash:${AUTOMATE_VERSION:-latest} \
  --peer ${HOST_IP:-172.17.0.1} --bind elasticsearch:elasticsearch5.default --bind rabbitmq:rabbitmq.default --listen-gossip 0.0.0.0:9652 --listen-http 0.0.0.0:9662

# workflow-server

# NOTE: The Supervisor won't start if /hab/sup/default/LOCK exists
# if it exists, you'll need to account for its removal in order to start the services
echo "Removing any stale LOCK files for workflow-server"
sudo rm -f "${DATA_MOUNT:-/mnt/hab}/workflow-server_sup/default/LOCK"
sudo -E docker run --rm -it \
  --name="workflow-server" \
  --env="HAB_WORKFLOW_SERVER=
enterprise = \"${ENTERPRISE:-default}\"
default_admin_password = \"${ADMIN_PASSWORD:-chefrocks}\"
[data_collector]
token = \"${AUTOMATE_TOKEN:-93a49a4f2482c64126f7b6015e6b0f30284287ee4054ff8807fb63d9cbd1c506}\"
" \
  --env="PATH=/bin" \
  --volume ${DATA_MOUNT:-/mnt/hab}/passwd:/etc/passwd:ro \
  --volume ${DATA_MOUNT:-/mnt/hab}/group:/etc/group:ro \
  --volume ${DATA_MOUNT:-/mnt/hab}/workflow-server_svc:/hab/svc \
  --volume ${DATA_MOUNT:-/mnt/hab}/workflow-server_sup:/hab/sup \
  --volume ${DATA_MOUNT:-/mnt/hab}/maintenance:/var/opt/delivery/delivery/etc \
  --cap-drop="NET_BIND_SERVICE" \
  --cap-drop="SETUID" \
  --cap-drop="SETGID" \
  --user="${USER_ID:-42}:${GROUP_ID:-42}" \
  --network=host \
  --detach=true \
  ${AUTOMATE_DOCKER_ORIGIN:-chefserverofficial}/workflow-server:${AUTOMATE_VERSION:-latest} \
  --peer ${HOST_IP:-172.17.0.1} --bind database:postgresql.default --bind elasticsearch:elasticsearch5.default --bind rabbitmq:rabbitmq.default --listen-gossip 0.0.0.0:9653 --listen-http 0.0.0.0:9663

# notifications

# NOTE: The Supervisor won't start if /hab/sup/default/LOCK exists
# if it exists, you'll need to account for its removal in order to start the services
echo "Removing any stale LOCK files for workflow-server"
sudo rm -f "${DATA_MOUNT:-/mnt/hab}/workflow-server_sup/default/LOCK"
sudo -E docker run --rm -it \
  --name="notifications" \
  --env="PATH=/bin" \
  --volume ${DATA_MOUNT:-/mnt/hab}/passwd:/etc/passwd:ro \
  --volume ${DATA_MOUNT:-/mnt/hab}/group:/etc/group:ro \
  --volume ${DATA_MOUNT:-/mnt/hab}/notifications_svc:/hab/svc \
  --volume ${DATA_MOUNT:-/mnt/hab}/notifications_sup:/hab/sup \
  --cap-drop="NET_BIND_SERVICE" \
  --cap-drop="SETUID" \
  --cap-drop="SETGID" \
  --user="${USER_ID:-42}:${GROUP_ID:-42}" \
  --network=host \
  --detach=true \
  ${AUTOMATE_DOCKER_ORIGIN:-chefserverofficial}/notifications:${AUTOMATE_VERSION:-latest} \
  --peer ${HOST_IP:-172.17.0.1} --bind elasticsearch:elasticsearch5.default --bind rabbitmq:rabbitmq.default --listen-gossip 0.0.0.0:9654 --listen-http 0.0.0.0:9664

# compliance

# NOTE: The Supervisor won't start if /hab/sup/default/LOCK exists
# if it exists, you'll need to account for its removal in order to start the services
echo "Removing any stale LOCK files for compliance"
sudo rm -f "${DATA_MOUNT:-/mnt/hab}/compliance_sup/default/LOCK"
sudo -E docker run --rm -it \
  --name="compliance" \
  --env="PATH=/bin" \
  --volume ${DATA_MOUNT:-/mnt/hab}/passwd:/etc/passwd:ro \
  --volume ${DATA_MOUNT:-/mnt/hab}/group:/etc/group:ro \
  --volume ${DATA_MOUNT:-/mnt/hab}/compliance_svc:/hab/svc \
  --volume ${DATA_MOUNT:-/mnt/hab}/compliance_sup:/hab/sup \
  --cap-drop="NET_BIND_SERVICE" \
  --cap-drop="SETUID" \
  --cap-drop="SETGID" \
  --user="${USER_ID:-42}:${GROUP_ID:-42}" \
  --network=host \
  --detach=true \
  ${AUTOMATE_DOCKER_ORIGIN:-chefserverofficial}/compliance:${AUTOMATE_VERSION:-latest} \
  --peer ${HOST_IP:-172.17.0.1} --bind elasticsearch:elasticsearch5.default --listen-gossip 0.0.0.0:9655 --listen-http 0.0.0.0:9665

# automate-nginx

# NOTE: The Supervisor won't start if /hab/sup/default/LOCK exists
# if it exists, you'll need to account for its removal in order to start the services
echo "Removing any stale LOCK files for automate-nginx"
sudo rm -f "${DATA_MOUNT:-/mnt/hab}/automate-nginx_sup/default/LOCK"
sudo -E docker run --rm -it \
  --name="automate-nginx" \
  --env="HAB_AUTOMATE_NGINX: |
port = ${PILOT_HTTP_PORT:-8080}
ssl_port = ${PILOT_HTTPS_PORT:-8443}
" \
  --env="PATH=/bin" \
  --volume ${DATA_MOUNT:-/mnt/hab}/passwd:/etc/passwd:ro \
  --volume ${DATA_MOUNT:-/mnt/hab}/group:/etc/group:ro \
  --volume ${DATA_MOUNT:-/mnt/hab}/automate-nginx_svc:/hab/svc \
  --volume ${DATA_MOUNT:-/mnt/hab}/automate-nginx_sup:/hab/sup \
  --volume ${DATA_MOUNT:-/mnt/hab}/maintenance:/var/opt/delivery/delivery/etc \
  --cap-drop="NET_BIND_SERVICE" \
  --cap-drop="SETUID" \
  --cap-drop="SETGID" \
  --user="${USER_ID:-42}:${GROUP_ID:-42}" \
  --network=host \
  --detach=true \
  ${AUTOMATE_DOCKER_ORIGIN:-chefserverofficial}/automate-nginx:${AUTOMATE_VERSION:-latest} \
  --peer ${HOST_IP:-172.17.0.1} --bind compliance:compliance.default --bind elasticsearch:elasticsearch5.default --bind workflow:workflow-server.default --bind notifications:notifications.default --listen-gossip 0.0.0.0:9656 --listen-http 0.0.0.0:9666
