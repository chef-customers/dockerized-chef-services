## Start up the Chef Server using docker run ...

```bash

#!/bin/bash

# Configurable environment variables:
# HAB_ORIGIN - denotes the docker origin (dockerhub ID) - set to `chefservernonroot` for non-root or `chefserverofficial` for root enabled containers
# VERSION -  the version identifier tag on the packages
# HOST_IP - the IP address of the docker host. 172.17.0.1 is commonly the docker0 interface which is fine
# AUTOMATE_ENABLED - enable the Automate data collector (true or false)
# AUTOMATE_SERVER - the IP address or hostname of the Automate server
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
  --name="chef-server-ctl" \
  --env="HAB_CHEF_SERVER_CTL=[chef_server_api]
ip = \"${HOST_IP:-172.17.0.1}\"
[secrets.data_collector]
token = \"${AUTOMATE_TOKEN:-93a49a4f2482c64126f7b6015e6b0f30284287ee4054ff8807fb63d9cbd1c506}\"
" \
  --env="PATH=/bin" \
  --env="HAB_NON_ROOT=1" \
  --user="${USER_ID:-42}:${GROUP_ID:-42}" \
  --cap-drop="NET_BIND_SERVICE" \
  --cap-drop="SETUID" \
  --cap-drop="SETGID" \
  --network=host \
  --restart=unless-stopped \
  --detach=true \
  ${HAB_ORIGIN:-chefservernonroot}/chef-server-ctl:${VERSION:-latest} \
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
  --name="oc_id" \
  --env="PATH=/bin" \
  --env="HAB_NON_ROOT=1" \
  --user="${USER_ID:-42}:${GROUP_ID:-42}" \
  --cap-drop="NET_BIND_SERVICE" \
  --cap-drop="SETUID" \
  --cap-drop="SETGID" \
  --network=host \
  --restart=unless-stopped \
  --detach=true \
  ${HAB_ORIGIN:-chefservernonroot}/oc_id:${VERSION:-latest} \
  --peer ${HOST_IP:-172.17.0.1} --bind database:postgresql.default --bind chef-server-ctl:chef-server-ctl.default --listen-gossip 0.0.0.0:9652 --listen-http 0.0.0.0:9662

sudo -E docker run \
  --name="bookshelf" \
  --env="PATH=/bin" \
  --env="HAB_NON_ROOT=1" \
  --user="${USER_ID:-42}:${GROUP_ID:-42}" \
  --cap-drop="NET_BIND_SERVICE" \
  --cap-drop="SETUID" \
  --cap-drop="SETGID" \
  --network=host \
  --restart=unless-stopped \
  --detach=true \
  ${HAB_ORIGIN:-chefservernonroot}/bookshelf:${VERSION:-latest} \
  --peer ${HOST_IP:-172.17.0.1} --bind database:postgresql.default --bind chef-server-ctl:chef-server-ctl.default --listen-gossip 0.0.0.0:9653 --listen-http 0.0.0.0:9663

sudo -E docker run \
  --name="oc_bifrost" \
  --env="PATH=/bin" \
  --env="HAB_NON_ROOT=1" \
  --user="${USER_ID:-42}:${GROUP_ID:-42}" \
  --cap-drop="NET_BIND_SERVICE" \
  --cap-drop="SETUID" \
  --cap-drop="SETGID" \
  --network=host \
  --restart=unless-stopped \
  --detach=true \
  ${HAB_ORIGIN:-chefservernonroot}/oc_bifrost:${VERSION:-latest} \
  --peer ${HOST_IP:-172.17.0.1} --bind database:postgresql.default --bind chef-server-ctl:chef-server-ctl.default --listen-gossip 0.0.0.0:9654 --listen-http 0.0.0.0:9664

sudo -E docker run \
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
  --env="HAB_NON_ROOT=1" \
  --user="${USER_ID:-42}:${GROUP_ID:-42}" \
  --cap-drop="NET_BIND_SERVICE" \
  --cap-drop="SETUID" \
  --cap-drop="SETGID" \
  --network=host \
  --restart=unless-stopped \
  --detach=true \
  ${HAB_ORIGIN:-chefservernonroot}/oc_erchef:${VERSION:-latest} \
  --peer ${HOST_IP:-172.17.0.1} --bind bookshelf:bookshelf.default --bind oc_bifrost:oc_bifrost.default --bind database:postgresql.default --bind elasticsearch:elasticsearch.default --bind chef-server-ctl:chef-server-ctl.default --listen-gossip 0.0.0.0:9655 --listen-http 0.0.0.0:9665

sudo -E docker run \
  --name="chef-server-nginx" \
  --env="PATH=/bin" \
  --env="HAB_NON_ROOT=1" \
  --user="${USER_ID:-42}:${GROUP_ID:-42}" \
  --volume="${DATA_MOUNT:-/mnt/hab}/nginx:/hab/svc/chef-server-nginx/data:Z" \
  --cap-drop="NET_BIND_SERVICE" \
  --cap-drop="SETUID" \
  --cap-drop="SETGID" \
  --network=host \
  --restart=unless-stopped \
  --detach=true \
  ${HAB_ORIGIN:-chefservernonroot}/chef-server-nginx:${VERSION:-latest} \
  --peer ${HOST_IP:-172.17.0.1} --bind oc_erchef:oc_erchef.default --bind oc_bifrost:oc_bifrost.default --bind oc_id:oc_id.default --bind bookshelf:bookshelf.default --bind elasticsearch:elasticsearch.default --bind chef-server-ctl:chef-server-ctl.default --listen-gossip 0.0.0.0:9656 --listen-http 0.0.0.0:9666
```
