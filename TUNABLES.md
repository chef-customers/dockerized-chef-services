The following is a list of all of the configurable values for all of the services.  These are displayed in TOML format, taken directly from the `default.toml` file for each of the habitat services.

To apply them, simply inject the configuration using the methodology here: https://www.habitat.sh/docs/using-habitat/#config-updates

For dockerized setups, we inject the environment variable using `docker run` or `docker-compose` like so:

```
HAB_MYPACKAGE=
[toml_header]
toml_string = "foo"
toml_number = 4
```

## Chef Server and Shared components

Some components are consumed directly out of the public Habitat Builder service. For these, it's best to go directly to the package info page, and scroll down to the `Configuration` section

| Service name | What it does | Link to package information and configuration |
| ------------ | :----------: | --------------------------------------------: |
| Elasticsearch | Search software | [https://bldr.habitat.sh/#/pkgs/core/elasticsearch5/latest] |
| PostgreSQL    | Relational database | [https://bldr.habitat.sh/#/pkgs/core/postgresql/latest] |
| RabbitMQ      | Message Queue       | [https://bldr.habitat.sh/#/pkgs/core/rabbitmq/latest] |
| oc_erchef     | Chef Server API     | [https://bldr.habitat.sh/#/pkgs/chef-server/oc_erchef/latest] |
| oc_bifrost    | Chef AuthZ API      | [https://bldr.habitat.sh/#/pkgs/chef-server/oc_bifrost/latest] |
| oc_id         | Chef OAuth2 API     | [https://bldr.habitat.sh/#/pkgs/chef-server/oc_id/latest] |
| bookshelf     | Chef Cookbook store | [https://bldr.habitat.sh/#/pkgs/chef-server/bookshelf/latest] |
| chef-server-ctl | Manages secrets inside of Chef server | [https://bldr.habitat.sh/#/pkgs/chef-server/chef-server-ctl/latest] |
| chef-server-nginx | Chef Server Gateway | [https://bldr.habitat.sh/#/pkgs/chef-server/chef-server-nginx/latest] |

## Chef Automate Components

### Workflow Service

What it does: Primary API Service for Chef Automate 1 (name preserved for historical reasons)

Configuration
```toml
##
# Documented settings for the "delivery" service
#
# See https://docs.chef.io/config_rb_delivery.html
# and https://docs.chef.io/config_rb_delivery_optional_settings.html#delivery
# for definitions and defaults.
#
a2_mode = false
api_port = 9611
audit_max_events = 100
ca_cert_chain_depth = 2
chef_config = "/var/opt/delivery/delivery/etc/erlang.cfg"
chef_server_webui = "https://127.0.0.1"
chef_private_key="/etc/chef/delivery.pem"
chef_server="chef-server"
chef_username="delivery"
db_name = "delivery"
db_pool_init_count = 20
db_pool_max_count = 100
default_search="""(recipes:delivery_builder OR recipes:delivery_builder\\\\:\\\\:default
                  OR recipes:delivery_build OR recipes:delivery_build\\\\:\\\\:default
                  OR tags:delivery-build-node)"""
dir = "/var/opt/delivery/delivery"
elasticsearch_url = "http://127.0.0.1:9200"
etc_dir = "/var/opt/delivery/delivery/etc"
git_repo_template = "git_repo_template"
git_repos = "git/repos"
git_working_tree_dir = "git_workspace"
is_dev_box = true

# used in the post-run hook for ltpoc
enterprise = 'Demo'
default_admin_password = 'password'
builder_key = "builder_key"
# Automate listens  on the default route ip address unless this value is set
#
# When we finish, this should end up being commented out by default. The
# default behavior should be to bind to the default interface, which Habitat
# exposes as `sys.ip`.
#
# As of now, however, we need to listen on 0.0.0.0 (all interfaces) because the
# update git hook (in
# /server/apps/delivery/priv/git_repo_template/hooks/update) has "localhost"
# hard-coded for the host to connect to, so if we're not listening on
# 127.0.0.1, that hook will fail.
#
# https://chefio.atlassian.net/browse/ET-495 is open to fix this.
listen = "0.0.0.0"

log_directory = "/var/log/delivery/delivery"
phase_job_confirmation_timeout = 300000 # "5m"
port = 9611
primary = true
push_jobs_max_retries = 3
push_jobs_overall_timeout =  7200 # "2h"
push_jobs_run_timeout = 4500 # "75m"
read_ttl = 604800 # "7d"
sql_password = "pokemon"
sql_repl_password = "pokemon_repl"
sql_repl_user = "delivery_repl"
sql_user = "delivery"
use_ssl_termination = false
write_ttl = 604800 # "7d"
vip = "127.0.0.1"
insights_enable = true
visibility_enable = true

  ##
  # The following settings are also used by the delivery service,
  # but are undocumented.
  #

  # Used for linking to the Opsworks Console
  # console_name = nil
  # console_url = nil

  marketplace_licensing = false
  no_ssl_verification = []
  telemetry_api = "https://telemetry.chef.io"
  telemetry_enabled = false

  [delivery]
  omnibus_version = "0.0.1"
  api_proto = "http"
  deliv_git_ssh_base_command = "git"
  deliv_chef_config = "erlang.cfg"
  git_executable = ""
  trusted_certificates_file = "'/etc/ssl/certs/ca-certificates.crt'"
  disaster_recovery_mode = "standalone"
  lsyncd_stat_path = "/lsyncd/supervise/stat"
  fips_mode = false

  [auth]
  [auth.oidc]
  client_id="587a8fc0b5fb5a846214"
  client_secret="dac40a235d6e1659b2e0221cd22cf609bca3964eb6a4a9fd79fe10ff4ce11ffd18f3a49a7f21016dbd7ef285753c1eca37d5"
  client_redirect_uri="null"
  oidc_signing_key_file="/etc/delivery/oidc_signing_key.pem"
  saml_entity_id="https://saml.chef.io"

  [auth.ldap]
  enabled = false
  attr_full_name = "fullName"
  attr_login = "sAMAccountName"
  attr_mail = "mail"
  base_dn = "OU=Employees,OU=Domain users,DC=examplecorp,DC=com"
  bind_dn = "ldapbind"
  bind_dn_password = "secret123"
  encryption = "start_tls"
  hosts = []
  port = 3269
  timeout = 5000

  #
  # End of undocumented delivery service settings
  ##

[data_collector]
token = "93a49a4f2482c64126f7b6015e6b0f30284287ee4054ff8807fb63d9cbd1c506"

[log_rotation]
file_maxbytes = 10240000
num_to_keep = 10

[ssl_certificates]

#
# End of delivery service settings
##

[deliv_notify]
config = []

[git]
authkeys = "git/.ssh/authorized_keys"

[lsyncd]
log_directory = "/var/log/lsyncd/lsync-status.log"

[postgresql]
vip = "postgres"
port = 5432

[proxy]
## Required values to use a proxy
# host = "localhost"
# port = 3128
# user = "proxyuser"
# password = "proxypass"
no_proxy = ["localhost", "127.0.0.1"]

[rabbitmq]
management_enabled = true
management_password = "chefrocks"
management_port = 15672
management_user = "insights"
password = "chefrocks"
use_ssl = false
port = 5672
vip = "rabbitmq"
vhost = "/insights"
user = "insights"

[ssh_git]
hostname = "delivery"
host_address = "0.0.0.0"
port = 8989
```

### Logstash

What it does: Data Ingestion system for Chef Automate

Configuration
```toml
rabbitmq_host="localhost"
rabbitmq_vhost="/insights"
rabbitmq_user="insights"
rabbitmq_pass="chefrocks"

# Tunables
java_heap_size="1g"
java_opts="-XX:+UseParNewGC -XX:+UseConcMarkSweepGC -Djava.awt.headless=true -XX:CMSInitiatingOccupancyFraction=75 -XX:+UseCMSInitiatingOccupancyOnly -XX:+HeapDumpOnOutOfMemoryError"
pipeline_workers=4
pipeline_batch_size=125
pipeline_batch_delay=5

[elasticsearch]

schema_version = "1"

[kibana]

version = "4.6.1"
```

### Automate Nginx

What it does: Frontend gateway for Chef Automate

Configuration
```toml
# The maximum accepted body size for a client request, as indicated by the
# Content-Length request header. When the maximum accepted body size is greater
# than this value, a 413 Request Entity Too Large error is returned.
client_max_body_size = "250m"

# The fully qualified domain name for the server. This should be set to the
# address at which people will be accessing the server.
server_name = "automate"

# Port used for http traffic
port = 8080

# Port used for SSL traffic
ssl_port = 8443

# # SSL protocols and ciphers

# These options provide the current best security with TSLv1
# ssl_protocols = "-ALL +TLSv1"
# ssl_ciphers = "RC4:!MD5"

# This might be necessary for auditors that want no MEDIUM security ciphers and
# don't understand BEAST attacks
# ssl_protocols = "-ALL +SSLv3 +TLSv1"
# ssl_ciphers = "HIGH:!MEDIUM:!LOW:!ADH:!kEDH:!aNULL:!eNULL:!EXP:!SSLv2:!SEED:!CAMELLIA:!PSK"

# Based off of the Mozilla recommended cipher suite
# https://mozilla.github.io/server-side-tls/ssl-config-generator/?server=nginx-1.8.1&openssl=1.0.1u&hsts=no&profile=modern
# NOTE: testssl.sh warns about Secure Renegotiation (CVE-2009-3555),
#       but this might be ok since it should only allow for renegotiating from one
#       of the allowed ciphers to another one.
# NOTE: AES256-GCM-SHA384 is not part of the Mozilla suite but has been added to
#       support AWS's classic ELB's. Without it the health checks will fail.
ssl_protocols = "TLSv1.2"
ssl_ciphers = "ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-SHA384:ECDHE-RSA-AES256-SHA384:ECDHE-ECDSA-AES128-SHA256:ECDHE-RSA-AES128-SHA256:AES256-GCM-SHA384:!aNULL:!eNULL:!EXPORT"
ssl_certificate = "/hab/svc/automate-nginx/data/cert"
ssl_certificate_key = "/hab/svc/automate-nginx/data/key"
worker_connections = 1024
sendfile = "on"
tcp_nodelay = "on"
tcp_nopush = "on"
keepalive_timeout = 65

[gzip]
enabled = "on"
comp_level = 2
http_version = "1.0"
proxied = "any"
types = [ "text/plain", "text/css",
  "application/x-javascript", "text/xml",
  "application/javascript", "application/xml",
  "application/xml+rss", "text/javascript",
  "application/json"
]

# Options for Kibana
[kibana]
# Whether or not Kibana is enabled. If this is false, /kibana will be a 404.
enable = true
# If this is false, anyone can access /kibana without restrictions.
enable_auth = true
```

### Reaper

What it does: Provides data management and retention control for Automate's data in Elasticsearch (based on Elastic Curator)

Configuration
```toml
# Configuation options for Reaper service
[reaper]

# How often to run the reaper, in seconds.
interval = 600

# If `true`, reaper will run and take action as needed.
enable = true

# Valid options are `delete` or `archive`.
mode = "delete"

# Any indices older than this value will have action taken on them.
retention_period_in_days = 2

# If `true`, evasive maneuvers may be taken during the Reaper run. See the below section on Evasive Maneuvers for more information.
evasive_maneuvers_enabled = false

# Evasive maneuvers will be taken if the available free space is less than this value.
free_space_threshold_percent = 90

# Name of repository to use in curator
repository = "insights"

# TODO: Add all the options

# Options for workflow server
[workflow]

# Host and port for workflow API. Will be used if no binding is present.
host = "localhost"
port = 8080

# Options for Elasticsearch Curator
[elasticsearch]

# Elasticsearch host and port. Used if no elasticsearch binding is present
host = "elasticsearch"
port = 9200

# Prefix for elasticsearch
prefix = ""
```
