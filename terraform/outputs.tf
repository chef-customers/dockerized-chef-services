output "automate_server_ssh" {
  value = "ssh -i ${var.aws_key_pair_file} ${var.aws_ami_user}@${aws_instance.automate_cluster.*.public_dns[0]}"
}

output "automate_admin_user" {
  value = "admin"
}

output "automate_admin_password" {
  value = "${var.automate_admin_password}"
}

output "chef_server_ssh" {
  value = "ssh -i ${var.aws_key_pair_file} ${var.aws_ami_user}@${aws_instance.automate_cluster.*.public_dns[1]}"
}
