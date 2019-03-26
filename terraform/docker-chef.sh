#!/bin/bash

# Configurable shell environment variables:
#
# CHEF_SERVER_DOCKER_ORIGIN - denotes the docker origin (dockerhub ID) or default to `chefserverofficial`
# AUTOMATE_DOCKER_ORIGIN - denotes the docker origin (dockerhub ID) or default to `chefdemo`
# CHEF_SERVER_VERSION -  the version identifier tag on the Chef Server packages
# AUTOMATE_VERSION -  the version identifier tag on the postgresql and elasticsearch packages from the `chefdemo` docker origin
# AUTOMATE_ENABLED - enable the Automate data collector (true or false)
# AUTOMATE_SERVER - the IP address or hostname of the Automate server
# AUTOMATE_TOKEN - the token for the Automate server data collector
# ENTERPRISE - the name of the Automate enterprise to create
# ADMIN_PASSWORD - the initial password to set for the 'admin' user in the Automate UI
# DATA_MOUNT - the mount point for the data
# USER_ID - the user ID to use (numeric)
# GROUP_ID - the group ID to use (numeric)
# DOCKER_REQUIRES_SUDO - [true|false] whether or not docker requires sudo to run when invoked by the user running this script
# DOCKER_LOG_DRIVER - Logging driver for the container or default to journald
# The above variables should all be set in a file named env.sh that lives beside this script.

# Determine the IP address of the docker host.
# we attempt to match the 1st occurrence if multiple IPs are returned
HOST_IP=$(hostname --ip-address | sed -n '1p')

THISDIR="$(dirname "$(which "$0")")"
if [ -f "${THISDIR}/env.sh" ]; then
 . "${THISDIR}/env.sh"
fi

banner="This is a control script for starting|stopping Chef Server and Chef Automate docker services.

You must specify the following options:
 -s [automate|chef-server]           REQUIRED: Services type: Chef Server or Chef Automate
 -a [stop|start]                     REQUIRED: Action type: start or stop services
 -n [container name]                 OPTIONAL: The docker container name. Leaving blank implies ALL
 -l [path]                           OPTIONAL: Apply the Automate License from [path] (mutually exclusive with [a|n|g] options)
 -g [gather-logs]                    OPTIONAL: Save container logs to .gz (mutually exclusive with [a|l] options)
 -h                                  OPTIONAL: Print this help message

 ex. $0 -s chef-server -a start                    : starts up all Chef Server services
 ex. $0 -s automate -a stop -n logstash            : stops Automate's logstash service
 ex. $0 -s automate -g                             : saves all Automate container logs to .gz
 ex. $0 -s chef-server -g -n postgresql            : saves Chef Server Postgresql logs to .gz
 ex. $0 -s automate -l /path/to/delivery.license   : applies Automate license from /path/to/delivery.license

"

usage () {
  echo "$banner"
  exit 1
}

if [ $# -eq 0 ]; then
  usage
fi

while getopts "s:a:n:l:gh" opt; do
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
    g)
      export GATHER_LOGS=true
      ;;
    l)
      export AUTOMATE_LICENSE_PATH=$OPTARG
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
postgresql["toml"]="HAB_POSTGRESQL=[superuser]
name = 'hab'
password = 'chefrocks'
"
postgresql["supargs"]=""

declare -A elasticsearch
elasticsearch["image"]="${AUTOMATE_DOCKER_ORIGIN:-chefdemo}/elasticsearch5:${AUTOMATE_VERSION:-stable}"
elasticsearch["toml"]="HAB_ELASTICSEARCH5=[runtime]
heapsize = \"4g\"
"
elasticsearch["supargs"]="--peer ${HOST_IP:-172.17.0.1}"
elasticsearch["gossip"]="0.0.0.0:9650"
elasticsearch["http"]="0.0.0.0:9700"
elasticsearch["ctl"]="127.0.0.1:9800"

# Chef Server
#
declare -A chef_server_ctl
chef_server_ctl["image"]="${CHEF_SERVER_DOCKER_ORIGIN:-chefserverofficial}/chef-server-ctl:${CHEF_SERVER_VERSION:-stable}"
chef_server_ctl["toml"]="HAB_CHEF_SERVER_CTL=[chef_server_api]
ip = \"${HOST_IP:-172.17.0.1}\"
ssl_port = \"8443\"
[pedant_config]
search_server = \"http://${HOST_IP:-172.17.0.1}:9200\"
[secrets.data_collector]
token = \"${AUTOMATE_TOKEN:-93a49a4f2482c64126f7b6015e6b0f30284287ee4054ff8807fb63d9cbd1c506}\"
"
chef_server_ctl["supargs"]="--peer ${HOST_IP:-172.17.0.1}"
chef_server_ctl["gossip"]="0.0.0.0:9651"
chef_server_ctl["http"]="0.0.0.0:9701"
chef_server_ctl["ctl"]="127.0.0.1:9801"

declare -A oc_id
oc_id["image"]="${CHEF_SERVER_DOCKER_ORIGIN:-chefserverofficial}/oc_id:${CHEF_SERVER_VERSION:-stable}"
oc_id["toml"]=""
oc_id["supargs"]="--peer ${HOST_IP:-172.17.0.1} --bind database:postgresql.default --bind chef-server-ctl:chef-server-ctl.default"
oc_id["gossip"]="0.0.0.0:9652"
oc_id["http"]="0.0.0.0:9702"
oc_id["ctl"]="127.0.0.1:9802"

declare -A bookshelf
bookshelf["image"]="${CHEF_SERVER_DOCKER_ORIGIN:-chefserverofficial}/bookshelf:${CHEF_SERVER_VERSION:-stable}"
bookshelf["toml"]=""
bookshelf["supargs"]="--peer ${HOST_IP:-172.17.0.1} --bind database:postgresql.default --bind chef-server-ctl:chef-server-ctl.default"
bookshelf["gossip"]="0.0.0.0:9653"
bookshelf["http"]="0.0.0.0:9703"
bookshelf["ctl"]="127.0.0.1:9803"

declare -A oc_bifrost
oc_bifrost["image"]="${CHEF_SERVER_DOCKER_ORIGIN:-chefserverofficial}/oc_bifrost:${CHEF_SERVER_VERSION:-stable}"
oc_bifrost["toml"]=""
oc_bifrost["supargs"]="--peer ${HOST_IP:-172.17.0.1} --bind database:postgresql.default --bind chef-server-ctl:chef-server-ctl.default"
oc_bifrost["gossip"]="0.0.0.0:9654"
oc_bifrost["http"]="0.0.0.0:9704"
oc_bifrost["ctl"]="127.0.0.1:9804"

declare -A oc_erchef
oc_erchef["image"]="${CHEF_SERVER_DOCKER_ORIGIN:-chefserverofficial}/oc_erchef:${CHEF_SERVER_VERSION:-stable}"
oc_erchef["toml"]="HAB_OC_ERCHEF=[data_collector]
enabled = ${AUTOMATE_ENABLED:-false}
server = \"${AUTOMATE_SERVER:-localhost}\"
port = 443
[chef_authn]
keygen_cache_workers = 2
keygen_cache_size = 10
keygen_start_size = 0
keygen_timeout = 20000
[oc_chef_wm]
max_request_size = 2000000
"
oc_erchef["supargs"]="--peer ${HOST_IP:-172.17.0.1} --bind bookshelf:bookshelf.default --bind oc_bifrost:oc_bifrost.default --bind database:postgresql.default --bind elasticsearch:elasticsearch5.default --bind chef-server-ctl:chef-server-ctl.default"
oc_erchef["gossip"]="0.0.0.0:9655"
oc_erchef["http"]="0.0.0.0:9705"
oc_erchef["ctl"]="127.0.0.1:9805"

declare -A chef_server_nginx
chef_server_nginx["image"]="${CHEF_SERVER_DOCKER_ORIGIN:-chefserverofficial}/chef-server-nginx:${CHEF_SERVER_VERSION:-stable}"
chef_server_nginx["toml"]='HAB_CHEF_SERVER_NGINX=
access_log = "/dev/stdout"
'
chef_server_nginx["supargs"]="--peer ${HOST_IP:-172.17.0.1} --bind oc_erchef:oc_erchef.default --bind oc_bifrost:oc_bifrost.default --bind oc_id:oc_id.default --bind bookshelf:bookshelf.default --bind elasticsearch:elasticsearch5.default --bind chef-server-ctl:chef-server-ctl.default"
chef_server_nginx["gossip"]="0.0.0.0:9656"
chef_server_nginx["http"]="0.0.0.0:9706"
chef_server_nginx["ctl"]="127.0.0.1:9806"

# Automate
#

declare -A rabbitmq
rabbitmq["image"]="${AUTOMATE_DOCKER_ORIGIN:-chefdemo}/rabbitmq:${AUTOMATE_VERSION:-stable}"
rabbitmq["toml"]="HAB_RABBITMQ=[rabbitmq]
default_vhost = '/insights'
default_user = 'insights'
default_pass = 'chefrocks'
[rabbitmq.management]
enabled = true
"
rabbitmq["supargs"]="--peer ${HOST_IP:-172.17.0.1}"
rabbitmq["gossip"]="0.0.0.0:9657"
rabbitmq["http"]="0.0.0.0:9707"
rabbitmq["ctl"]="127.0.0.1:9807"

declare -A logstash
logstash["image"]="${AUTOMATE_DOCKER_ORIGIN:-chefdemo}/logstash:${AUTOMATE_VERSION:-stable}"
logstash["toml"]="HAB_LOGSTASH=
java_heap_size=\"2g\"
pipeline_batch_size=40
"
logstash["supargs"]="--peer ${HOST_IP:-172.17.0.1} --bind elasticsearch:elasticsearch5.default --bind rabbitmq:rabbitmq.default"
logstash["gossip"]="0.0.0.0:9658"
logstash["http"]="0.0.0.0:9708"
logstash["ctl"]="127.0.0.1:9808"

declare -A workflow_server
workflow_server["image"]="${AUTOMATE_DOCKER_ORIGIN:-chefdemo}/workflow-server:${AUTOMATE_VERSION:-stable}"
workflow_server["toml"]="HAB_WORKFLOW_SERVER=
enterprise = \"${ENTERPRISE:-default}\"
default_admin_password = \"${ADMIN_PASSWORD:-chefrocks}\"
[data_collector]
token = \"${AUTOMATE_TOKEN:-93a49a4f2482c64126f7b6015e6b0f30284287ee4054ff8807fb63d9cbd1c506}\"
[mlsa]
accept = true
"
workflow_server["supargs"]="--peer ${HOST_IP:-172.17.0.1} --bind database:postgresql.default --bind elasticsearch:elasticsearch5.default --bind rabbitmq:rabbitmq.default"
workflow_server["gossip"]="0.0.0.0:9659"
workflow_server["http"]="0.0.0.0:9709"
workflow_server["ctl"]="127.0.0.1:9809"

declare -A notifications
notifications["image"]="${AUTOMATE_DOCKER_ORIGIN:-chefdemo}/notifications:${AUTOMATE_VERSION:-stable}"
notifications["toml"]=""
notifications["supargs"]="--peer ${HOST_IP:-172.17.0.1} --bind elasticsearch:elasticsearch5.default --bind rabbitmq:rabbitmq.default"
notifications["gossip"]="0.0.0.0:9660"
notifications["http"]="0.0.0.0:9710"
notifications["ctl"]="127.0.0.1:9810"

declare -A compliance
compliance["image"]="${AUTOMATE_DOCKER_ORIGIN:-chefdemo}/compliance:${AUTOMATE_VERSION:-stable}"
compliance["toml"]="HAB_COMPLIANCE_SERVICE=[service]
host = \"0.0.0.0\"
[profiles]
secrets_key = \"12345678901234567890123456789012\"
"
compliance["supargs"]="--peer ${HOST_IP:-172.17.0.1} --bind postgresql:postgresql.default --bind elasticsearch:elasticsearch5.default --bind workflow:workflow-server.default"
compliance["gossip"]="0.0.0.0:9661"
compliance["http"]="0.0.0.0:9711"
compliance["ctl"]="127.0.0.1:9811"

declare -A automate_nginx
automate_nginx["image"]="${AUTOMATE_DOCKER_ORIGIN:-chefdemo}/automate-nginx:${AUTOMATE_VERSION:-stable}"
automate_nginx["toml"]="HAB_AUTOMATE_NGINX=
port = ${PILOT_HTTP_PORT:-8080}
ssl_port = ${PILOT_HTTPS_PORT:-8443}
[mlsa]
accept = true
"
automate_nginx["supargs"]="--peer ${HOST_IP:-172.17.0.1} --bind compliance:compliance.default --bind elasticsearch:elasticsearch5.default --bind workflow:workflow-server.default --bind notifications:notifications.default"
automate_nginx["gossip"]="0.0.0.0:9662"
automate_nginx["http"]="0.0.0.0:9712"
automate_nginx["ctl"]="127.0.0.1:9812"

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
  toml="$svc[toml]"
  gossip="$svc[gossip]"
  http="$svc[http]"
  ctl="$svc[ctl]"

  echo "Starting ${!image}"
  dirs="${DATA_MOUNT:-/mnt/hab}/${1}_svc ${DATA_MOUNT:-/mnt/hab}/${1}_sup ${DATA_MOUNT:-/mnt/hab}/${1}_launcher"
  echo "Ensuring $dirs directories exist and removing stale LOCK files"
  mkdir -p $dirs
  rm -f ${DATA_MOUNT:-/mnt/hab}/${1}_sup/default/LOCK
  $(sudo_cmd) docker run --rm -i \
    --name="${1}" \
    --env="HOME=/hab/svc/${1}/data" \
    --env="${!toml:-ILOVECHEF=1}" \
    --env="HAB_LISTEN_GOSSIP=${!gossip:-0.0.0.0:9638}" \
    --env="HAB_LISTEN_HTTP=${!http:-0.0.0.0:9631}" \
    --env="HAB_LISTEN_CTL=${!ctl:-127.0.0.1:9632}" \
    --volume ${DATA_MOUNT:-/mnt/hab}/passwd:/etc/passwd:ro \
    --volume ${DATA_MOUNT:-/mnt/hab}/group:/etc/group:ro \
    --volume ${DATA_MOUNT:-/mnt/hab}/${1}_svc:/hab/svc \
    --volume ${DATA_MOUNT:-/mnt/hab}/${1}_sup:/hab/sup \
    --volume ${DATA_MOUNT:-/mnt/hab}/${1}_launcher:/hab/launcher \
    --cap-drop="NET_BIND_SERVICE" \
    --cap-drop="SETUID" \
    --cap-drop="SETGID" \
    --ulimit nofile=65536:65536 \
    --user="${USER_ID:-42}:${GROUP_ID:-42}" \
    --network=host \
    -d=${DOCKER_DETACH_CONTAINER:-true} \
    --log-driver=${DOCKER_LOG_DRIVER:-journald} \
    ${!image} \
    ${!supargs} --permanent-peer
}

stop_svc () {
  echo "Stopping $1"
  $(sudo_cmd) docker stop "$1" >/dev/null 2>&1 || true
}

stop_all () {
  echo "Stopping ALL.."
  case "$1" in
    chef-server)
      for svc in chef-server-nginx oc_erchef oc_id bookshelf oc_bifrost elasticsearch chef-server-ctl postgresql; do
        stop_svc "$svc"
      done
      ;;
    automate)
      for svc in automate-nginx workflow-server notifications compliance logstash rabbitmq elasticsearch postgresql; do
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

tar_svc_logs() {
  [[ ! -z "$SERVICE_ACTION" ]] && usage
  [[ ! -z "$AUTOMATE_LICENSE_PATH" ]] && usage

  arr=("$@")

  LOG_DIR="$(hostname -s)-$(date +'%Y%m%d%H%M%S')-logs"
  mkdir $LOG_DIR

  for svc in "${arr[@]}"; do
    echo "Gathering logs for $svc"
    $(sudo_cmd) docker logs "$svc" > $LOG_DIR/$svc.log
  done

  LOG_GZ="$LOG_DIR.tar.gz"
  tar czf $LOG_GZ $LOG_DIR
  rm -rf $LOG_DIR
  echo "Logs saved to $LOG_GZ"
}

gatherlogs_all () {
  echo "Gathering logs for all $SERVICE_TYPE services.."
  case "$1" in
    chef-server)
      array=("chef-server-nginx" "oc_erchef" "oc_id" "bookshelf" "oc_bifrost" "elasticsearch" "chef-server-ctl" "postgresql")
      ;;
    automate)
      array=("automate-nginx" "workflow-server" "notifications" "compliance" "logstash" "rabbitmq" "elasticsearch" "postgresql")
      ;;
    *)
      echo "not implemented"
      exit 1
      ;;
  esac
  tar_svc_logs "${array[@]}"
  exit 0
}

gatherlogs_svc () {
  echo "Gathering logs for $SERVICE_TYPE $1"
  array=("$1")
  tar_svc_logs "${array[@]}"
  exit 0
}

apply_automate_license () {
  [[ ! -z "$SERVICE_ACTION" ]] && usage
  [[ ! -z "$SERVICE_NAME" ]] && usage
  [[ ! -z "$GATHER_LOGS" ]] && usage

  echo "Applying license from $1 to workflow-server Habitat service"
  cp -f $1 ${DATA_MOUNT:-/mnt/hab}/workflow-server_svc/workflow-server/var/delivery.license
  $(sudo_cmd) docker exec -it workflow-server hab file upload workflow-server.default $(date +'%s') /hab/svc/workflow-server/var/delivery.license --remote-sup 127.0.0.1:9809
  exit 0
}

start_all () {
  case "$1" in
    chef-server)
    docker_svc_start "postgresql"
    sleep 10
    for svc in chef-server-ctl elasticsearch oc_id bookshelf oc_bifrost oc_erchef chef-server-nginx; do
        docker_svc_start "$svc"
      done
      ;;
    automate)
    docker_svc_start "postgresql"
    sleep 10
    for svc in rabbitmq elasticsearch logstash workflow-server notifications compliance automate-nginx; do
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
    case "$AUTOMATE_LICENSE_PATH" in
      "")
        ;;
       *)
        apply_automate_license "$AUTOMATE_LICENSE_PATH"
        ;;
    esac
    case "$GATHER_LOGS" in
      true)
        case "$SERVICE_NAME" in
          # optional service name
          "")
            gatherlogs_all "$SERVICE_TYPE"
            ;;
          *)
            gatherlogs_svc "$SERVICE_NAME"
            ;;
        esac
        ;;
    esac
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
