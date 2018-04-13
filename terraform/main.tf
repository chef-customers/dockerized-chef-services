terraform {
  required_version = ">= 0.11.0"
}

# Change these from defaults as needed in `terraform.tfvars`
variable "aws_key_pair_name" { }
variable "aws_key_pair_file" { }
variable "tag_dept" { }
variable "tag_contact" { }
variable "automate_admin_password" { }
variable "docker_requires_sudo" { }

# General AWS variables - likely ok to leave as default
variable "aws_region" { default = "us-west-2" }
variable "aws_profile" { default = "default" }
variable "aws_vpc" { default = "vpc-41d45124" }
variable "aws_subnet" { default = "subnet-7424b611" }
variable "default_security_group" { default = "sg-c9beb2ac" }
variable "aws_ami_user" { default = "centos" }
variable "aws_ami_id" { default = "" }  # leave blank to auto-select the latest highperf CentOS 7 image
variable "aws_instance_names" { default = ["automate", "chef-server"] }
variable "aws_instance_types" { default = ["m5.large", "m5.large"] } # Automate, Chef Server

# chef services - also ok to leave as default
variable "container_username" { default = "chef-dev-ux" }
variable "container_uid" { default = "9999" }
variable "container_gid" { default = "8888" }
variable "container_data_mount" { default = "/mnt/data" }
variable "automate_enterprise" { default = "brewinc" }
variable "docker_host_ip" { default = "$(hostname --ip-address)" }
variable "automate_enabled" { default = "true" }
variable "automate_token" { default = "93a49a4f2482c64126f7b6015e6b0f30284287ee4054ff8807fb63d9cbd1c506" }
variable "chef_server_docker_origin" { default = "chefserverofficial" }
variable "automate_docker_origin" { default = "chefdemo" }
variable "chef_server_version" { default = "stable" }
variable "automate_version" { default = "stable" }

provider "aws" {
  region  = "${var.aws_region}"
  profile = "${var.aws_profile}" // uses ~/.aws/credentials by default
}

resource "random_id" "cluster_id" { byte_length = 4 }

data "aws_ami" "centos" {
  most_recent = true
  owners = ["446539779517"]

  filter {
    name   = "name"
    values = ["chef-highperf-centos7-*"]
  }
}

data "template_file" "env_sh" {
  template = "${file("${path.module}/env.tpl")}"

  vars {
    container_username = "${var.container_username}"
    container_uid = "${var.container_uid}"
    container_gid = "${var.container_gid}"
    container_data_mount = "${var.container_data_mount}"
    automate_enterprise = "${var.automate_enterprise}"
    automate_admin_password = "${var.automate_admin_password}"
    automate_enabled = "${var.automate_enabled}"
    automate_token = "${var.automate_token}"
    chef_server_docker_origin = "${var.chef_server_docker_origin}"
    chef_server_version = "${var.chef_server_version}"
    automate_docker_origin = "${var.automate_docker_origin}"
    automate_version = "${var.automate_version}"
    docker_requires_sudo = "${var.docker_requires_sudo}"
  }
}

data "template_file" "group" {
  template = "${file("${path.module}/group.tpl")}"

  vars {
    container_username = "${var.container_username}"
    container_gid = "${var.container_gid}"
  }
}

data "template_file" "passwd" {
  template = "${file("${path.module}/passwd.tpl")}"

  vars {
    container_username = "${var.container_username}"
    container_uid = "${var.container_uid}"
    container_gid = "${var.container_gid}"
  }
}

resource "aws_instance" "automate_cluster" {
  count = 2
  # We execute this resource twice, creating two aws_instances. We can reference each instance via count.index
  # For example: aws_instance.automate_cluster.*.public_dns[count.index]
  # count.index will be one of:
  # 0 == Automate Server
  # 1 == Chef Server
  # The advantage of this is two-fold:
  #  1. we do not need duplicated provisioner blocks for each
  #  2. the provisioner blocks will execute in parallel - this cuts provisioning times roughly in half

  connection {
    user        = "${var.aws_ami_user}"
    private_key = "${file("${var.aws_key_pair_file}")}"
  }

  ami                         = "${var.aws_ami_id == "" ? data.aws_ami.centos.id : var.aws_ami_id}"
  instance_type               = "${element(var.aws_instance_types, count.index)}"
  key_name                    = "${var.aws_key_pair_name}"
  subnet_id                   = "${var.aws_subnet}"
  vpc_security_group_ids      = ["${var.default_security_group}"]
  associate_public_ip_address = true
  ebs_optimized               = true

  root_block_device {
    delete_on_termination = true
    volume_size           = 200
    volume_type           = "gp2"
  }

  tags {
    Name      = "dockerized-${element(var.aws_instance_names, count.index)}-${random_id.cluster_id.hex}"
    X-Dept    = "${var.tag_dept}"
    X-Contact = "${var.tag_contact}"
  }
}

resource "null_resource" "provision_cluster" {
  count = 2
  # We execute this resource twice. See resource "aws_instance" notes above.

  connection {
    user        = "${var.aws_ami_user}"
    private_key = "${file("${var.aws_key_pair_file}")}"
    host        = "${aws_instance.automate_cluster.*.public_dns[count.index]}"
  }

  provisioner "file" {
    source      = "${path.module}/setup.sh"
    destination = "/home/${var.aws_ami_user}/setup.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo chmod a+x /home/${var.aws_ami_user}/setup.sh",
      "sudo /home/${var.aws_ami_user}/setup.sh",
      "sudo groupadd -g ${var.container_gid} ${var.container_username}",
      "sudo adduser -u ${var.container_uid} -g ${var.container_gid} -G docker -m ${var.container_username}",
      "sudo chmod 777 /home/${var.container_username}",
      "sudo mkdir -p ${var.container_data_mount}",
      "sudo chmod 777 ${var.container_data_mount}"
    ]
  }

  provisioner "file" {
    content     = "${data.template_file.env_sh.rendered}"
    destination = "/home/${var.container_username}/env.sh"
  }

  provisioner "file" {
    source      = "${path.module}/docker-chef.sh"
    destination = "/home/${var.container_username}/docker-chef.sh"
  }

  provisioner "file" {
    content     = "${data.template_file.group.rendered}"
    destination = "${var.container_data_mount}/group"
  }

  provisioner "file" {
    content     = "${data.template_file.passwd.rendered}"
    destination = "${var.container_data_mount}/passwd"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo chmod a+x /home/${var.container_username}/*sh",
      "sudo sed -i 's/AUTOMATE_SERVER_IP_VALUE/${aws_instance.automate_cluster.*.private_ip[0]}/' /home/${var.container_username}/env.sh",
      "sudo chown -R ${var.container_uid}:${var.container_gid} ${var.container_data_mount}",
      "sudo chown -R ${var.container_uid}:${var.container_gid} /home/${var.container_username}",
      "sudo -Hu ${var.container_username} /home/${var.container_username}/docker-chef.sh -s ${element(var.aws_instance_names, count.index)} -a start"
    ]
  }
}

output "automate_server" {
  value = "https://${aws_instance.automate_cluster.*.public_dns[0]}"
}

output "automate_admin_user" {
  value = "admin"
}

output "automate_admin_password" {
  value = "${var.automate_admin_password}"
}

output "chef_server" {
  value = "https://${aws_instance.automate_cluster.*.public_dns[1]}"
}
