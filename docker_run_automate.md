## Start up Automate using docker run ...

```bash

#!/bin/bash

# Configurable environment variables:
# HAB_ORIGIN - denotes the docker origin (dockerhub ID) - set to `chefservernonroot` for non-root or `chefserverofficial` for root enabled containers
# VERSION -  the version identifier tag on the packages
# HOST_IP - the IP address of the docker host. 172.17.0.1 is commonly the docker0 interface which is fine
# ENTERPRISE - the name of the Automate enterprise to create
# ADMIN_PASSWORD - the initial password to set for the 'admin' user in the Automate UI
# AUTOMATE_TOKEN - the token for the Automate server data collector
# DATA_MOUNT - the mount point for the data
# USER_ID - the user ID to use
# GROUP_ID - the group ID to use
# LABEL_NAME - the name of the custom docker label to use
# LABEL_VALUE - the value to assign to the custom docker label

sudo -E docker run \
  --name="postgresql" \
  --env="HAB_POSTGRESQL=[superuser]
name = 'hab'
password = 'chefrocks'
" \
  --env="PATH=/bin" \
  --env="HAB_NON_ROOT=1" \
  --user="${USER_ID:-42}:${GROUP_ID:-42}" \
  --volume="${DATA_MOUNT:-/mnt/hab}/postgresql:/hab/svc/postgresql/data:Z" \
  --cap-drop="NET_BIND_SERVICE" \
  --cap-drop="SETUID" \
  --cap-drop="SETGID" \
  --network=host \
  --restart=unless-stopped \
  --detach=true \
  ${HAB_ORIGIN:-chefservernonroot}/postgresql:${VERSION:-latest} \
  start chef-server/postgresql

sudo -E docker run \
  --name="rabbitmq" \
  --env="HAB_RABBITMQ=[rabbitmq]
default_vhost = '/insights'
default_user = 'insights'
default_pass = 'chefrocks'
[rabbitmq.management]
enabled = true
" \
  --env="PATH=/bin" \
  --env="HAB_NON_ROOT=1" \
  --user="${USER_ID:-42}:${GROUP_ID:-42}" \
  --volume="${DATA_MOUNT:-/mnt/hab}/rabbitmq:/hab/svc/rabbitmq/data:Z" \
  --cap-drop="NET_BIND_SERVICE" \
  --cap-drop="SETUID" \
  --cap-drop="SETGID" \
  --network=host \
  --restart=unless-stopped \
  --detach=true \
  ${HAB_ORIGIN:-chefservernonroot}/rabbitmq:${VERSION:-latest} \
  --peer ${HOST_IP:-172.17.0.1} --listen-gossip 0.0.0.0:9650 --listen-http 0.0.0.0:9660

sudo -E docker run \
  --name="elasticsearch" \
  --env="PATH=/bin" \
  --env="HAB_NON_ROOT=1" \
  --user="${USER_ID:-42}:${GROUP_ID:-42}" \
  --volume="${DATA_MOUNT:-/mnt/hab}/elasticsearch:/hab/svc/elasticsearch/data:Z" \
  --cap-drop="NET_BIND_SERVICE" \
  --cap-drop="SETUID" \
  --cap-drop="SETGID" \
  --network=host \
  --restart=unless-stopped \
  --detach=true \
  --ulimit nofile=65536:65536 \
  ${HAB_ORIGIN:-chefservernonroot}/elasticsearch:${VERSION:-latest} \
  --peer ${HOST_IP:-172.17.0.1} --listen-gossip 0.0.0.0:9651 --listen-http 0.0.0.0:9661

sudo -E docker run \
  --name="logstash" \
  --env="PATH=/bin" \
  --env="HAB_NON_ROOT=1" \
  --user="${USER_ID:-42}:${GROUP_ID:-42}" \
  --cap-drop="NET_BIND_SERVICE" \
  --cap-drop="SETUID" \
  --cap-drop="SETGID" \
  --network=host \
  --restart=unless-stopped \
  --detach=true \
  ${HAB_ORIGIN:-chefservernonroot}/logstash:${VERSION:-latest} \
  --peer ${HOST_IP:-172.17.0.1} --bind elasticsearch:elasticsearch.default --bind rabbitmq:rabbitmq.default --listen-gossip 0.0.0.0:9652 --listen-http 0.0.0.0:9662

sudo -E docker run \
  --name="workflow-server" \
  --env="HAB_WORKFLOW_SERVER=
enterprise = \"${ENTERPRISE:-default}\"
default_admin_password = \"${ADMIN_PASSWORD:-chefrocks}\"
[data_collector]
token = \"${AUTOMATE_TOKEN:-93a49a4f2482c64126f7b6015e6b0f30284287ee4054ff8807fb63d9cbd1c506}\"
" \
  --env="PATH=/bin" \
  --env="HAB_NON_ROOT=1" \
  --user="${USER_ID:-42}:${GROUP_ID:-42}" \
  --volume="${DATA_MOUNT:-/mnt/hab}/maintenance:/var/opt/delivery/delivery/etc:Z" \
  --volume="${DATA_MOUNT:-/mnt/hab}/workflow:/hab/svc/workflow-server/data:Z" \
  --cap-drop="NET_BIND_SERVICE" \
  --cap-drop="SETUID" \
  --cap-drop="SETGID" \
  --network=host \
  --restart=unless-stopped \
  --detach=true \
  ${HAB_ORIGIN:-chefservernonroot}/workflow-server:${VERSION:-latest} \
  --peer ${HOST_IP:-172.17.0.1} --bind database:postgresql.default --bind elasticsearch:elasticsearch.default --bind rabbitmq:rabbitmq.default --listen-gossip 0.0.0.0:9653 --listen-http 0.0.0.0:9663

sudo -E docker run \
  --name="notifications" \
  --env="PATH=/bin" \
  --env="HAB_NON_ROOT=1" \
  --user="${USER_ID:-42}:${GROUP_ID:-42}" \
  --cap-drop="NET_BIND_SERVICE" \
  --cap-drop="SETUID" \
  --cap-drop="SETGID" \
  --network=host \
  --restart=unless-stopped \
  --detach=true \
  ${HAB_ORIGIN:-chefservernonroot}/notifications:${VERSION:-latest} \
  --peer ${HOST_IP:-172.17.0.1} --bind elasticsearch:elasticsearch.default --bind rabbitmq:rabbitmq.default --listen-gossip 0.0.0.0:9654 --listen-http 0.0.0.0:9664

sudo -E docker run \
  --name="compliance" \
  --env="PATH=/bin" \
  --env="HAB_NON_ROOT=1" \
  --user="${USER_ID:-42}:${GROUP_ID:-42}" \
  --volume="${DATA_MOUNT:-/mnt/hab}/compliance:/hab/svc/compliance/data:Z" \
  --cap-drop="NET_BIND_SERVICE" \
  --cap-drop="SETUID" \
  --cap-drop="SETGID" \
  --network=host \
  --restart=unless-stopped \
  --detach=true \
  ${HAB_ORIGIN:-chefservernonroot}/compliance:${VERSION:-latest} \
  --peer ${HOST_IP:-172.17.0.1} --bind elasticsearch:elasticsearch.default --listen-gossip 0.0.0.0:9655 --listen-http 0.0.0.0:9665

sudo -E docker run \
  --name="automate-nginx" \
  --env="HAB_AUTOMATE_NGINX: |
port = ${PILOT_HTTP_PORT:-8080}
ssl_port = ${PILOT_HTTPS_PORT:-8443}
" \
  --env="PATH=/bin" \
  --env="HAB_NON_ROOT=1" \
  --user="${USER_ID:-42}:${GROUP_ID:-42}" \
  --volume="${DATA_MOUNT:-/mnt/hab}/nginx:/hab/svc/automate-nginx/data:Z" \
  --volume="${DATA_MOUNT:-/mnt/hab}/maintenance:/var/opt/delivery/delivery/etc" \
  --cap-drop="NET_BIND_SERVICE" \
  --cap-drop="SETUID" \
  --cap-drop="SETGID" \
  --network=host \
  --restart=unless-stopped \
  --detach=true \
  ${HAB_ORIGIN:-chefservernonroot}/automate-nginx:${VERSION:-latest} \
  --peer ${HOST_IP:-172.17.0.1} --bind compliance:compliance.default --bind elasticsearch:elasticsearch.default --bind workflow:workflow-server.default --bind notifications:notifications.default --listen-gossip 0.0.0.0:9656 --listen-http 0.0.0.0:9666
```
