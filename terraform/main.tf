terraform {
  required_version = ">= 0.11.0"
}

provider "aws" {
  region  = "${var.aws_region}"
  profile = "${var.aws_profile}"
}

resource "random_id" "cluster_id" {
  byte_length = 4
}

data "aws_ami" "centos" {
  most_recent = true
  owners      = ["446539779517"]

  filter {
    name   = "name"
    values = ["chef-highperf-centos7-*"]
  }
}

data "template_file" "env_sh" {
  template = "${file("${path.module}/env.tpl")}"

  vars {
    container_username        = "${var.container_username}"
    container_uid             = "${var.container_uid}"
    container_gid             = "${var.container_gid}"
    container_data_mount      = "${var.container_data_mount}"
    automate_enterprise       = "${var.automate_enterprise}"
    automate_admin_password   = "${var.automate_admin_password}"
    automate_enabled          = "${var.automate_enabled}"
    automate_token            = "${var.automate_token}"
    chef_server_docker_origin = "${var.chef_server_docker_origin}"
    chef_server_version       = "${var.chef_server_version}"
    automate_docker_origin    = "${var.automate_docker_origin}"
    automate_version          = "${var.automate_version}"
    docker_requires_sudo      = "${var.docker_requires_sudo}"
    docker_detach_container   = "${var.docker_detach_container}"
  }
}

data "template_file" "group" {
  template = "${file("${path.module}/group.tpl")}"

  vars {
    container_username = "${var.container_username}"
    container_gid      = "${var.container_gid}"
  }
}

data "template_file" "passwd" {
  template = "${file("${path.module}/passwd.tpl")}"

  vars {
    container_username = "${var.container_username}"
    container_uid      = "${var.container_uid}"
    container_gid      = "${var.container_gid}"
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
    Name      = "dockerized-${element(var.tag_name, count.index)}-${random_id.cluster_id.hex}"
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
      "sudo chmod 777 ${var.container_data_mount}",
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
  provisioner "file" {
    content     = "${var.ctl_secret}"
    destination = "${var.container_data_mount}/CTL_SECRET"
  }
  provisioner "remote-exec" {
    inline = [
      "sudo chmod a+x /home/${var.container_username}/*sh",
      "sudo sed -i 's/AUTOMATE_SERVER_IP_VALUE/${aws_instance.automate_cluster.*.private_ip[0]}/' /home/${var.container_username}/env.sh",
      "sudo chown -R ${var.container_uid}:${var.container_gid} ${var.container_data_mount}",
      "sudo chown -R ${var.container_uid}:${var.container_gid} /home/${var.container_username}",
      "sudo -Hu ${var.container_username} /home/${var.container_username}/docker-chef.sh -s ${element(var.tag_name, count.index)} -a start",
    ]
  }
}
