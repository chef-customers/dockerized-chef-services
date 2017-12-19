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
variable "aws_key_pair_name" { }
variable "aws_key_pair_file" { }
variable "tag_dept" { }
variable "tag_contact" { }

# docker variables
variable "docker_compose_path" { default = "/usr/local/bin/docker-compose" }
variable "enterprise_name" { default = "dockerize" }
variable "admin_password" { default = "SuperSecurePassword" }
variable "automate_token" { default = "93a49a4f2482c64126f7b6015e6b0f30284287ee4054ff8807fb63d9cbd1c506" } # must be 32 characters

#
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

resource "aws_instance" "automate_server" {
  connection {
    user        = "${var.aws_ami_user}"
    private_key = "${file("${var.aws_key_pair_file}")}"
  }

  ami                         = "${var.aws_ami_id == "" ? data.aws_ami.centos.id : var.aws_ami_id}"
  instance_type               = "${var.automate_server_instance_type}"
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
    Name      = "dockerized-automate-server-${random_id.cluster_id.hex}"
    X-Dept    = "${var.tag_dept}"
    X-Contact = "${var.tag_contact}"
  }

  provisioner "file" {
    source      = "automate.yml"
    destination = "/home/${var.aws_ami_user}/docker-compose.yml"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo iptables -A PREROUTING -t nat -p tcp --dport 80 -j REDIRECT --to-port 8080",
      "sudo iptables -A PREROUTING -t nat -p tcp --dport 443 -j REDIRECT --to-port 8443",
      "export ENTERPRISE=${var.enterprise_name}",
      "export ADMIN_PASSWORD=${var.admin_password}",
      "export AUTOMATE_TOKEN=${var.automate_token}",
      "sleep 10",
      "sudo -E ${var.docker_compose_path} --no-ansi up -d"
    ]
  }
}

resource "aws_instance" "chef_server" {
  connection {
    user        = "${var.aws_ami_user}"
    private_key = "${file("${var.aws_key_pair_file}")}"
  }

  ami                         = "${var.aws_ami_id == "" ? data.aws_ami.centos.id : var.aws_ami_id}"
  instance_type               = "${var.chef_server_instance_type}"
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
    Name      = "dockerized-chef-server-${random_id.cluster_id.hex}"
    X-Dept    = "${var.tag_dept}"
    X-Contact = "${var.tag_contact}"
  }

  provisioner "file" {
    source      = "chef-server.yml"
    destination = "/home/${var.aws_ami_user}/docker-compose.yml"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo iptables -A PREROUTING -t nat -p tcp --dport 80 -j REDIRECT --to-port 8080",
      "sudo iptables -A PREROUTING -t nat -p tcp --dport 443 -j REDIRECT --to-port 8443",
      "sudo iptables -t nat -A OUTPUT -o lo -p tcp --dport 80 -j REDIRECT --to-port 8080",
      "sudo iptables -t nat -A OUTPUT -o lo -p tcp --dport 443 -j REDIRECT --to-port 8443",
      "export AUTOMATE_ENABLED=true",
      "export AUTOMATE_SERVER=${aws_instance.automate_server.private_ip}",
      "export AUTOMATE_TOKEN=${var.automate_token}",
      "sleep 10",
      "sudo -E ${var.docker_compose_path} --no-ansi up -d"
    ]
  }
}

output "automate_server" {
  value = "https://${aws_instance.automate_server.public_dns}"
}

output "automate_admin_user" {
  value = "admin"
}

output "automate_admin_password" {
  value = "${var.admin_password}"
}

output "chef_server" {
  value = "https://${aws_instance.chef_server.public_dns}"
}
