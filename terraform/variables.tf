////////////////////////////////
// Required variables. Create a terraform.tfvars.

variable "aws_key_pair_name" {
  description = "The name of the key pair to associate with your instances. Required for SSH access."
}

variable "aws_key_pair_file" {
  description = "The path to the file on disk for the private key associated with the AWS key pair associated with your instances. Required for SSH access."
}

variable "tag_dept" {
  description = "The department at your company responsible for these resources."
}

variable "tag_contact" {
  description = "The email address associated with the person or team that is standing up this resource. Used to contact if problems occur."
}

variable "automate_admin_password" {
  description = "The admin password to log in to the Chef Automate web interface."
}

variable "docker_requires_sudo" {
  description = "[true|false] whether or not docker requires sudo to run."
}

////////////////////////////////
// AWS

variable "aws_region" {
  default     = "us-west-2"
  description = "The name of the selected AWS region / datacenter."
}

variable "aws_profile" {
  default     = "default"
  description = "The AWS profile to use from your ~/.aws/credentials file."
}

variable "aws_vpc" {
  default     = "vpc-41d45124"
  description = "The VPC resources will be created under."
}

variable "aws_subnet" {
  default     = "subnet-7424b611"
  description = "The subnet resources will be created under."
}

variable "default_security_group" {
  default     = "sg-c9beb2ac"
  description = "The security group resources will be created under."
}

variable "aws_ami_user" {
  default     = "centos"
  description = "The user used for SSH connections and path variables."
}

variable "aws_ami_id" {
  default     = ""
  description = "The AMI id to use for the base image for instances. Leave blank to auto-select the latest high performance CentOS 7 image."
}

variable "tag_name" {
  default     = ["automate", "chef-server"]
  description = "An array of instance names, for each instance created. Appears in the AWS UI for identifying instances."
}

variable "aws_instance_types" {
  default     = ["m5.large", "m5.large"]
  description = "An array of instance types (sizes). tag_name indicates which instances map to which type."
}

////////////////////////////////
// Chef Services

variable "container_username" {
  default     = "chef-dev-ux"
  description = "The container username added with groupadd and into /etc/passwd."
}

variable "container_uid" {
  default     = "9999"
  description = "The user id used to set permissions on the container host."
}

variable "container_gid" {
  default     = "8888"
  description = "The group id used to set permission on the container host."
}

variable "container_data_mount" {
  default     = "/mnt/data"
  description = "The data mount created on each docker host."
}

variable "automate_enterprise" {
  default     = "brewinc"
  description = "The name of the enterprise used to set up Chef Automate."
}

variable "automate_enabled" {
  default     = "true"
  description = "[true|false] Enable the Automate data collector."
}

variable "automate_token" {
  default     = "93a49a4f2482c64126f7b6015e6b0f30284287ee4054ff8807fb63d9cbd1c506"
  description = "The token for the Automate data collector."
}

variable "chef_server_docker_origin" {
  default     = "chefserverofficial"
  description = "The docker origin (dockerhub ID) from where to pull down docker images."
}

variable "automate_docker_origin" {
  default     = "chefdemo"
  description = "The docker origin (dockerhub ID) from where to pull down docker images."
}

variable "chef_server_version" {
  default     = "latest"
  description = "The version of the Chef Server container to use. latest, or a tag from: https://hub.docker.com/r/chefserverofficial/oc_erchef/tags/"
}

variable "automate_version" {
  default     = "stable"
  description = "The version of the Chef Automate container to use. stable, or a tag from: https://hub.docker.com/r/chefdemo/workflow-server/tags/"
}

variable "docker_detach_container" {
  default = "true"
}
