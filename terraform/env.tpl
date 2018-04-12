#!/bin/bash

export LC_ALL=en_US.UTF-8

export USER_ID=${container_uid}
export GROUP_ID=${container_gid}
export DATA_MOUNT=${container_data_mount}
export ENTERPRISE=${automate_enterprise}
export ADMIN_PASSWORD=${automate_admin_password}
export HOST_IP=$(hostname --ip-address)
export AUTOMATE_ENABLED=${automate_enabled}
export AUTOMATE_SERVER=AUTOMATE_SERVER_IP_VALUE
export AUTOMATE_TOKEN=${automate_token}
export CHEF_SERVER_DOCKER_ORIGIN=${chef_server_docker_origin}
export CHEF_SERVER_VERSION=${chef_server_version}
export AUTOMATE_DOCKER_ORIGIN=${automate_docker_origin}
export AUTOMATE_VERSION=${automate_version}
export DOCKER_REQUIRES_SUDO=${docker_requires_sudo}
