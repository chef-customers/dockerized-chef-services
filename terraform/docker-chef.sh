#!/bin/bash

# Configurable shell environment variables:
#
# CHEF_SERVER_DOCKER_ORIGIN - denotes the docker origin (dockerhub ID) or default to `chefserverofficial`
# AUTOMATE_DOCKER_ORIGIN - denotes the docker origin (dockerhub ID) or default to `chefdemo`
# CHEF_SERVER_VERSION -  the version identifier tag on the Chef Server packages
# AUTOMATE_VERSION -  the version identifier tag on the postgresql and elasticsearch packages from the `chefdemo` docker origin
# HOST_IP - the IP address of the docker host. 172.17.0.1 is commonly the docker0 interface which is fine
# AUTOMATE_ENABLED - enable the Automate data collector (true or false)
# AUTOMATE_SERVER - the IP address or hostname of the Automate server
# AUTOMATE_TOKEN - the token for the Automate server data collector
# ENTERPRISE - the name of the Automate enterprise to create
# ADMIN_PASSWORD - the initial password to set for the 'admin' user in the Automate UI
# DATA_MOUNT - the mount point for the data
# USER_ID - the user ID to use (numeric)
# GROUP_ID - the group ID to use (numeric)
# DOCKER_REQUIRES_SUDO - [true|false] whether or not docker requires sudo to run when invoked by the user running this script

# The above variables should all be set in a file named env.sh that lives beside this script.
THISDIR="$(dirname "$(which "$0")")"
if [ -f "${THISDIR}/env.sh" ]; then
 . "${THISDIR}/env.sh"
fi

banner="This is a control script for starting|stopping Chef Server and Chef Automate docker services.

You must specify the following options:
 -s [automate|chef-server]           REQUIRED: Services type: Chef Server or Chef Automate
 -a [stop|start]                     REQUIRED: Action type: start or stop services
 -n [container name]                 OPTIONAL: The docker container name. Leaving blank implies ALL
 -h                                  OPTIONAL: Print this help message

 ex. $0 -s chef-server -a start            # starts up all Chef Server services
 ex. $0 -s automate -a stop -n logstash    # stops Automate's logstash service

"

usage () {
  echo "$banner"
  exit 1
}

if [ $# -eq 0 ]; then
  usage
fi

while getopts "s:a:n:h" opt; do
  case $opt in
    s)
      echo "Service type: $OPTARG"
      export SERVICE_TYPE=$OPTARG
      ;;
    a)
      echo "Service action: $OPTARG"
      export SERVICE_ACTION=$OPTARG
      ;;
    n)
      echo "Service name: $OPTARG"
      export SERVICE_NAME=$OPTARG
      ;;
    h)
      usage
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      exit 1
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      exit 1
      ;;
  esac
done

# Service Definitinons
#

declare -A postgresql
postgresql["image"]="${AUTOMATE_DOCKER_ORIGIN:-chefdemo}/postgresql:${AUTOMATE_VERSION:-stable}"
postgresql["env"]="HAB_POSTGRESQL=[superuser]
name = 'hab'
password = 'chefrocks'
"
postgresql["supargs"]=""

declare -A elasticsearch
elasticsearch["image"]="${AUTOMATE_DOCKER_ORIGIN:-chefdemo}/elasticsearch5:${AUTOMATE_VERSION:-stable}"
elasticsearch["env"]=""
elasticsearch["supargs"]="--peer ${HOST_IP:-172.17.0.1} --listen-gossip 0.0.0.0:9651 --listen-http 0.0.0.0:9661"

# Chef Server
#
declare -A chef_server_ctl
chef_server_ctl["image"]="${CHEF_SERVER_DOCKER_ORIGIN:-chefserverofficial}/chef-server-ctl:${CHEF_SERVER_VERSION:-stable}"
chef_server_ctl["env"]="HAB_CHEF_SERVER_CTL=[chef_server_api]
ip = \"${HOST_IP:-172.17.0.1}\"
ssl_port = \"8443\"
[secrets.data_collector]
token = \"${AUTOMATE_TOKEN:-93a49a4f2482c64126f7b6015e6b0f30284287ee4054ff8807fb63d9cbd1c506}\"
"
chef_server_ctl["supargs"]="--peer ${HOST_IP:-172.17.0.1} --listen-gossip 0.0.0.0:9650 --listen-http 0.0.0.0:9660"

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

# Automate
#

declare -A rabbitmq
rabbitmq["image"]="${AUTOMATE_DOCKER_ORIGIN:-chefdemo}/rabbitmq:${AUTOMATE_VERSION:-stable}"
rabbitmq["env"]="HAB_RABBITMQ=[rabbitmq]
default_vhost = '/insights'
default_user = 'insights'
default_pass = 'chefrocks'
[rabbitmq.management]
enabled = true
"
rabbitmq["supargs"]="--peer ${HOST_IP:-172.17.0.1} --listen-gossip 0.0.0.0:9650 --listen-http 0.0.0.0:9660"

declare -A logstash
logstash["image"]="${AUTOMATE_DOCKER_ORIGIN:-chefdemo}/logstash:${AUTOMATE_VERSION:-stable}"
logstash["env"]=""
logstash["supargs"]="--peer ${HOST_IP:-172.17.0.1} --bind elasticsearch:elasticsearch5.default --bind rabbitmq:rabbitmq.default --listen-gossip 0.0.0.0:9652 --listen-http 0.0.0.0:9662"

declare -A workflow_server
workflow_server["image"]="${AUTOMATE_DOCKER_ORIGIN:-chefdemo}/workflow-server:${AUTOMATE_VERSION:-stable}"
workflow_server["env"]="HAB_WORKFLOW_SERVER=
enterprise = \"${ENTERPRISE:-default}\"
default_admin_password = \"${ADMIN_PASSWORD:-chefrocks}\"
[data_collector]
token = \"${AUTOMATE_TOKEN:-93a49a4f2482c64126f7b6015e6b0f30284287ee4054ff8807fb63d9cbd1c506}\"
[mlsa]
accept = true
"
workflow_server["supargs"]="--peer ${HOST_IP:-172.17.0.1} --bind database:postgresql.default --bind elasticsearch:elasticsearch5.default --bind rabbitmq:rabbitmq.default --listen-gossip 0.0.0.0:9653 --listen-http 0.0.0.0:9663"

declare -A notifications
notifications["image"]="${AUTOMATE_DOCKER_ORIGIN:-chefdemo}/notifications:${AUTOMATE_VERSION:-stable}"
notifications["env"]=""
notifications["supargs"]="--peer ${HOST_IP:-172.17.0.1} --bind elasticsearch:elasticsearch5.default --bind rabbitmq:rabbitmq.default --listen-gossip 0.0.0.0:9654 --listen-http 0.0.0.0:9664"

declare -A compliance
compliance["image"]="${AUTOMATE_DOCKER_ORIGIN:-chefdemo}/compliance:${AUTOMATE_VERSION:-stable}"
compliance["env"]="HAB_COMPLIANCE_SERVICE=[service]
host = \"0.0.0.0\"
[profiles]
secrets_key = \"12345678901234567890123456789012\"
"
compliance["supargs"]="--peer ${HOST_IP:-172.17.0.1} --bind postgresql:postgresql.default --bind elasticsearch:elasticsearch5.default --bind workflow:workflow-server.default --listen-gossip 0.0.0.0:9655 --listen-http 0.0.0.0:9665"

declare -A automate_nginx
automate_nginx["image"]="${AUTOMATE_DOCKER_ORIGIN:-chefdemo}/automate-nginx:${AUTOMATE_VERSION:-stable}"
automate_nginx["env"]="HAB_AUTOMATE_NGINX=
port = ${PILOT_HTTP_PORT:-8080}
ssl_port = ${PILOT_HTTPS_PORT:-8443}
[mlsa]
accept = true
"
automate_nginx["supargs"]="--peer ${HOST_IP:-172.17.0.1} --bind compliance:compliance.default --bind elasticsearch:elasticsearch5.default --bind workflow:workflow-server.default --bind notifications:notifications.default --listen-gossip 0.0.0.0:9656 --listen-http 0.0.0.0:9666"

# Service functions
#

sudo_cmd () {
  if [ "$DOCKER_REQUIRES_SUDO" == "true" ]; then
    echo "sudo -E "
  else
    echo ""
  fi
}

docker_svc_start () {
  # https://stackoverflow.com/questions/39297530/bash-use-variable-as-name-of-associative-array-when-calling-value
  svc=$(echo "$1"|tr '-' '_')
  image="$svc[image]"
  supargs="$svc[supargs]"
  env="$svc[env]"

  echo "Starting ${!image}"
  dirs="${DATA_MOUNT:-/mnt/hab}/${1}_svc ${DATA_MOUNT:-/mnt/hab}/${1}_sup"
  echo "Ensuring $dirs directories exist and removing stale LOCK files"
  mkdir -p $dirs
  rm -f ${DATA_MOUNT:-/mnt/hab}/${1}_sup/default/LOCK
  $(sudo_cmd) docker run --rm -it \
    --name="${1}" \
    --env="HOME=/hab/svc/${1}/data" \
    --env="${!env:-ILOVECHEF=1}" \
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
    ${!image} \
    ${!supargs}
}

stop_svc () {
  echo "Stopping $1"
  $(sudo_cmd) docker stop "$1" >/dev/null 2>&1 || true
}

stop_all () {
  echo "Stopping ALL.."
  case "$1" in
    chef-server)
      for svc in postgresql chef-server-ctl elasticsearch oc_id bookshelf oc_bifrost oc_erchef chef-server-nginx; do
        stop_svc "$svc"
      done
      ;;
    automate)
      for svc in postgresql rabbitmq elasticsearch logstash workflow-server notifications compliance automate-nginx; do
        stop_svc "$svc"
      done
      ;;
    *)
      echo "not implemented"
      ;;
  esac
  echo "Removing ${DATA_MOUNT:-/mnt/hab}/*_sup"
  rm -rf ${DATA_MOUNT:-/mnt/hab}/*_sup
}

start_all () {
  case "$1" in
    chef-server)
      for svc in postgresql chef-server-ctl elasticsearch oc_id bookshelf oc_bifrost oc_erchef chef-server-nginx; do
        docker_svc_start "$svc"
      done
      ;;
    automate)
      for svc in postgresql rabbitmq elasticsearch logstash workflow-server notifications compliance automate-nginx; do
        docker_svc_start "$svc"
      done
      ;;
    *)
      echo "not implemented"
      ;;
  esac
}

case "$SERVICE_TYPE" in
  # chef-server or automate
  "")
     usage
     ;;
  automate|chef-server)
    # start or stop
    case "$SERVICE_ACTION" in
      stop)
        case "$SERVICE_NAME" in
          # optional service name
          "")
            stop_all "$SERVICE_TYPE"
            ;;
          *)
            stop_svc "$SERVICE_NAME"
            ;;
        esac
        ;;
      start)
        case "$SERVICE_NAME" in
          # optional service name
          "")
            start_all "$SERVICE_TYPE"
            ;;
          *)
          docker_svc_start "$SERVICE_NAME"
          ;;
        esac
        ;;
      *)
        usage
        ;;
    esac
      ;;
  *)
    usage
    ;;
esac
