terraform {
  required_version = ">= 0.11.0"
}

# AWS variables - change these as needed
variable "aws_region" { default = "us-west-2" }
variable "aws_profile" { default = "default" }
variable "aws_vpc" { default = "vpc-41d45124" }
variable "aws_subnet" { default = "subnet-7424b611" }
variable "chef_server_instance_type" { default = "m5.xlarge" }
variable "automate_server_instance_type" { default = "m5.2xlarge" }
variable "default_security_group" { default = "sg-c9beb2ac" }
variable "aws_ami_user" { default = "centos" }
variable "aws_ami_id" { default = "" }  # leave blank to auto-select the latest highperf CentOS 7 image
variable "aws_instance_names" { default = ["automate-server", "chef-server"] }
variable "aws_instance_types" { default = ["m4.xlarge", "m4.2xlarge"] }
variable "aws_key_pair_name" { }
variable "aws_key_pair_file" { }
variable "tag_dept" { }
variable "tag_contact" { }
variable "container_username" { }
variable "container_uid" { }
variable "container_gid" { }
variable "container_data_mount" { }
variable "automate_enterprise" { }
variable "automate_admin_password" { }
variable "docker_host_ip" { }
variable "automate_enabled" { }
variable "automate_token" { }
variable "chef_server_docker_origin" { }
variable "automate_docker_origin" { }
variable "chef_server_version" { }
variable "automate_version" { }
variable "chef_server_org" { }

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
  # count.index
  # 0 Automate Server
  # 1 Chef Server
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

  connection {
    user        = "${var.aws_ami_user}"
    private_key = "${file("${var.aws_key_pair_file}")}"
    host        = "${aws_instance.automate_cluster.*.public_dns[count.index]}"
  }

  provisioner "file" {
    content     = "${data.template_file.env_sh.rendered}"
    destination = "/home/${var.aws_ami_user}/env.sh"
  }

  provisioner "file" {
    source      = "${path.module}/${element(var.aws_instance_names, count.index)}.sh"
    destination = "/home/${var.aws_ami_user}/${element(var.aws_instance_names, count.index)}.sh"
  }

  provisioner "file" {
    content     = "${data.template_file.group.rendered}"
    destination = "/home/${var.aws_ami_user}/group"
  }

  provisioner "file" {
    content     = "${data.template_file.passwd.rendered}"
    destination = "/home/${var.aws_ami_user}/passwd"
  }

  provisioner "file" {
    source      = "${path.module}/setup.sh"
    destination = "/home/${var.aws_ami_user}/setup.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo groupadd -g ${var.container_gid} ${var.container_username}",
      "sudo adduser -u ${var.container_uid} -g ${var.container_gid} -m ${var.container_username}",
      "sudo sed -i 's/AUTOMATE_SERVER_IP_VALUE/${aws_instance.automate_cluster.*.private_ip[0]}/' /home/${var.aws_ami_user}/env.sh",
      "sudo mkdir -p ${var.container_data_mount}",
      "sudo cp -f /home/${var.aws_ami_user}/group ${var.container_data_mount}",
      "sudo cp -f /home/${var.aws_ami_user}/passwd ${var.container_data_mount}",
      "sudo chown -R ${var.container_uid}:${var.container_gid} ${var.container_data_mount}",
      "sudo chmod u+x /home/${var.aws_ami_user}/*sh",
      "sudo /home/${var.aws_ami_user}/setup.sh",
      "/home/${var.aws_ami_user}/${element(var.aws_instance_names, count.index)}.sh start"
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
