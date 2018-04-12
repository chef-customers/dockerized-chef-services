#!/bin/bash

# Configurable shell environment variables:
# CHEF_SERVER_DOCKER_ORIGIN - denotes the docker origin (dockerhub ID) or default to `chefserverofficial`
# AUTOMATE_DOCKER_ORIGIN - denotes the docker origin (dockerhub ID) or default to `chefdemo`
# CHEF_SERVER_VERSION -  the version identifier tag on the Chef Server packages
# AUTOMATE_VERSION -  the version identifier tag on the postgresql and elasticsearch packages from the `chefdemo` docker origin
# HOST_IP - the IP address of the docker host. 172.17.0.1 is commonly the docker0 interface which is fine
# AUTOMATE_ENABLED - enable the Automate data collector (true or false)
# AUTOMATE_SERVER - the IP address or hostname of the Automate server
# AUTOMATE_TOKEN - the token for the Automate server data collector
# DATA_MOUNT - the mount point for the data
# USER_ID - the user ID to use (numeric)
# GROUP_ID - the group ID to use (numeric)
#
# The above variables should all be set in a file named env.sh that lives beside this script.

THISDIR="$(dirname "$(which "$0")")"
if [ -f "${THISDIR}/env.sh" ]; then
 echo "Setting ENVIRONMENT variables"
 . $THISDIR/env.sh
fi

docker_svc_start () {
  echo "Starting $1"
  dirs="${DATA_MOUNT:-/mnt/hab}/${1}_svc ${DATA_MOUNT:-/mnt/hab}/${1}_sup"
  echo "Ensuring $dirs directories exist and removing stale LOCK files"
  mkdir -p $dirs
  rm -f ${DATA_MOUNT:-/mnt/hab}/${1}_sup/default/LOCK
  docker run --rm -it \
    --name="${1}" \
    --env="${4:-ILOVECHEF=1}" \
    --volume ${DATA_MOUNT:-/mnt/hab}/passwd:/etc/passwd:ro \
    --volume ${DATA_MOUNT:-/mnt/hab}/group:/etc/group:ro \
    --volume ${DATA_MOUNT:-/mnt/hab}/${1}_svc:/hab/svc \
    --volume ${DATA_MOUNT:-/mnt/hab}/${1}_sup:/hab/sup \
    --cap-drop="NET_BIND_SERVICE" \
    --cap-drop="SETUID" \
    --cap-drop="SETGID" \
    --ulimit nofile=65536:65536 \
    --user="${USER_ID:-42}:${GROUP_ID:-42}" \
    --network=host \
    --detach=true \
    $2 \
    $3
}

declare -A postgresql
postgresql["image"]="${AUTOMATE_DOCKER_ORIGIN:-chefdemo}/postgresql:${AUTOMATE_VERSION:-stable}"
postgresql["env"]="HAB_POSTGRESQL=[superuser]
name = 'hab'
password = 'chefrocks'
"
postgresql["supargs"]=""

declare -A chef_server_ctl
chef_server_ctl["image"]="${CHEF_SERVER_DOCKER_ORIGIN:-chefserverofficial}/chef-server-ctl:${CHEF_SERVER_VERSION:-stable}"
chef_server_ctl["env"]="HAB_CHEF_SERVER_CTL=[chef_server_api]
ip = \"${HOST_IP:-172.17.0.1}\"
ssl_port = "8443"
[secrets.data_collector]
token = \"${AUTOMATE_TOKEN:-93a49a4f2482c64126f7b6015e6b0f30284287ee4054ff8807fb63d9cbd1c506}\"
"
chef_server_ctl["supargs"]="--peer ${HOST_IP:-172.17.0.1} --listen-gossip 0.0.0.0:9650 --listen-http 0.0.0.0:9660"

declare -A elasticsearch
elasticsearch["image"]="${AUTOMATE_DOCKER_ORIGIN:-chefdemo}/elasticsearch5:${AUTOMATE_VERSION:-stable}"
elasticsearch["env"]=""
elasticsearch["supargs"]="--peer ${HOST_IP:-172.17.0.1} --listen-gossip 0.0.0.0:9651 --listen-http 0.0.0.0:9661"

declare -A oc_id
oc_id["image"]="${CHEF_SERVER_DOCKER_ORIGIN:-chefserverofficial}/oc_id:${CHEF_SERVER_VERSION:-stable}"
oc_id["env"]=""
oc_id["supargs"]="--peer ${HOST_IP:-172.17.0.1} --bind database:postgresql.default --bind chef-server-ctl:chef-server-ctl.default --listen-gossip 0.0.0.0:9652 --listen-http 0.0.0.0:9662"

declare -A bookshelf
bookshelf["image"]="${CHEF_SERVER_DOCKER_ORIGIN:-chefserverofficial}/bookshelf:${CHEF_SERVER_VERSION:-stable}"
bookshelf["env"]=""
bookshelf["supargs"]="--peer ${HOST_IP:-172.17.0.1} --bind database:postgresql.default --bind chef-server-ctl:chef-server-ctl.default --listen-gossip 0.0.0.0:9653 --listen-http 0.0.0.0:9663"

declare -A oc_bifrost
oc_bifrost["image"]="${CHEF_SERVER_DOCKER_ORIGIN:-chefserverofficial}/oc_bifrost:${CHEF_SERVER_VERSION:-stable}"
oc_bifrost["env"]=""
oc_bifrost["supargs"]="--peer ${HOST_IP:-172.17.0.1} --bind database:postgresql.default --bind chef-server-ctl:chef-server-ctl.default --listen-gossip 0.0.0.0:9654 --listen-http 0.0.0.0:9664"

declare -A oc_erchef
oc_erchef["image"]="${CHEF_SERVER_DOCKER_ORIGIN:-chefserverofficial}/oc_erchef:${CHEF_SERVER_VERSION:-stable}"
oc_erchef["env"]="HAB_OC_ERCHEF=[data_collector]
enabled = ${AUTOMATE_ENABLED:-false}
server = \"${AUTOMATE_SERVER:-localhost}\"
port = 443
[chef_authn]
keygen_cache_workers = 2
keygen_cache_size = 10
keygen_start_size = 0
keygen_timeout = 20000
"
oc_erchef["supargs"]="--peer ${HOST_IP:-172.17.0.1} --bind bookshelf:bookshelf.default --bind oc_bifrost:oc_bifrost.default --bind database:postgresql.default --bind elasticsearch:elasticsearch5.default --bind chef-server-ctl:chef-server-ctl.default --listen-gossip 0.0.0.0:9655 --listen-http 0.0.0.0:9665"

declare -A chef_server_nginx
chef_server_nginx["image"]="${CHEF_SERVER_DOCKER_ORIGIN:-chefserverofficial}/chef-server-nginx:${CHEF_SERVER_VERSION:-stable}"
chef_server_nginx["env"]=""
chef_server_nginx["supargs"]="--peer ${HOST_IP:-172.17.0.1} --bind oc_erchef:oc_erchef.default --bind oc_bifrost:oc_bifrost.default --bind oc_id:oc_id.default --bind bookshelf:bookshelf.default --bind elasticsearch:elasticsearch5.default --bind chef-server-ctl:chef-server-ctl.default --listen-gossip 0.0.0.0:9656 --listen-http 0.0.0.0:9666"

stop_svc () {
  echo "Stopping $1"
  docker stop $1 >/dev/null 2>&1 || true
}

stop_all () {
  echo "Stopping ALL.."
  docker stop $(docker ps -aq) >/dev/null 2>&1 || true
  echo "Removing ${DATA_MOUNT:-/mnt/hab}/*_sup"
  rm -rf ${DATA_MOUNT:-/mnt/hab}/*_sup
}

start_all () {
  docker_svc_start "postgresql" "${postgresql[image]}" "${postgresql[supargs]}" "${postgresql[env]}"
  docker_svc_start "chef-server-ctl" "${chef_server_ctl[image]}" "${chef_server_ctl[supargs]}" "${chef_server_ctl[env]}"
  docker_svc_start "elasticsearch" "${elasticsearch[image]}" "${elasticsearch[supargs]}" "${elasticsearch[env]}"
  docker_svc_start "oc_id" "${oc_id[image]}" "${oc_id[supargs]}" "${oc_id[env]}"
  docker_svc_start "bookshelf" "${bookshelf[image]}" "${bookshelf[supargs]}" "${bookshelf[env]}"
  docker_svc_start "oc_bifrost" "${oc_bifrost[image]}" "${oc_bifrost[supargs]}" "${oc_bifrost[env]}"
  docker_svc_start "oc_erchef" "${oc_erchef[image]}" "${oc_erchef[supargs]}" "${oc_erchef[env]}"
  docker_svc_start "chef-server-nginx" "${chef_server_nginx[image]}" "${chef_server_nginx[supargs]}" "${chef_server_nginx[env]}"
}

case "$1" in
  stop)
    case "$2" in
      "")
        stop_all
        ;;
      *)
        stop_svc $2
        ;;
    esac
    ;;
  start)
    case "$2" in
      "")
        start_all
        ;;
      *)
      # https://stackoverflow.com/questions/39297530/bash-use-variable-as-name-of-associative-array-when-calling-value
      svc=$(echo $2|tr '-' '_')
      image=$svc[image]
      supargs=$svc[supargs]
      env=$svc[env]
      docker_svc_start "$2" "${!image}" "${!supargs}" "${!env}"
      ;;
    esac
  ;;
esac