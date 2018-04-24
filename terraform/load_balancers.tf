data "aws_subnet_ids" "aws_vpc_autosubnets" {
  vpc_id = "${var.aws_vpc}"
}

################################################################################
# ALB for Automate
################################################################################
resource "aws_lb" "automate" {
  name               = "automate-${random_id.cluster_id.hex}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["${var.default_security_group}"]
  subnets            = ["${data.aws_subnet_ids.aws_vpc_autosubnets.ids[0]}", "${data.aws_subnet_ids.aws_vpc_autosubnets.ids[2]}"]

  tags {
    X-Dept    = "${var.tag_dept}"
    X-Contact = "${var.tag_contact}"
    Created-By = "terraform"
  }
}

resource "aws_lb_target_group" "automate-http" {
  name     = "automate-http-${random_id.cluster_id.hex}"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = "${var.aws_vpc}"

  health_check {
    path = "/api/_status"
  }
}

resource "aws_lb_target_group" "automate-https" {
  name     = "automate-https-${random_id.cluster_id.hex}"
  port     = 8443
  protocol = "HTTPS"
  vpc_id   = "${var.aws_vpc}"

  health_check {
    path = "/api/_status"
    protocol = "HTTPS"
  }
}

resource "aws_lb_listener" "automate-http" {
  load_balancer_arn = "${aws_lb.automate.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_lb_target_group.automate-http.arn}"
    type             = "forward"
  }
}

resource "aws_lb_listener" "automate-https" {
  load_balancer_arn = "${aws_lb.automate.arn}"
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2015-05"
  certificate_arn   = "arn:aws:acm:us-west-2:446539779517:certificate/60f573b3-f8ed-48d9-a6d1-e89f79da2e8f"

  default_action {
    target_group_arn = "${aws_lb_target_group.automate-https.arn}"
    type             = "forward"
  }
}

resource "aws_lb_target_group_attachment" "automate-http" {
  target_group_arn = "${aws_lb_target_group.automate-http.arn}"
  target_id        = "${aws_instance.automate_cluster.*.id[0]}"
  port             = 8080
}

resource "aws_lb_target_group_attachment" "automate-https" {
  target_group_arn = "${aws_lb_target_group.automate-https.arn}"
  target_id        = "${aws_instance.automate_cluster.*.id[0]}"
  port             = 8443
}

output "automate_url" {
  value = "https://${aws_lb.automate.dns_name}"
}

################################################################################
# ALB for Chef Server
################################################################################
resource "aws_lb" "chefserver" {
  name               = "chefserver-${random_id.cluster_id.hex}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["${var.default_security_group}"]
  subnets            = ["${data.aws_subnet_ids.aws_vpc_autosubnets.ids[0]}", "${data.aws_subnet_ids.aws_vpc_autosubnets.ids[2]}"]

  tags {
    X-Dept    = "${var.tag_dept}"
    X-Contact = "${var.tag_contact}"
    Created-By = "terraform"
  }
}

resource "aws_lb_target_group" "chefserver" {
  name     = "chefserver-https-${random_id.cluster_id.hex}"
  port     = 8443
  protocol = "HTTPS"
  vpc_id   = "${var.aws_vpc}"

  health_check {
    path = "/_status"
    protocol = "HTTPS"
  }
}

resource "aws_lb_listener" "chefserver-http" {
  load_balancer_arn = "${aws_lb.chefserver.arn}"
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = "${aws_lb_target_group.chefserver.arn}"
    type             = "forward"
  }
}

resource "aws_lb_listener" "chefserver-https" {
  load_balancer_arn = "${aws_lb.chefserver.arn}"
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2015-05"
  certificate_arn   = "arn:aws:acm:us-west-2:446539779517:certificate/60f573b3-f8ed-48d9-a6d1-e89f79da2e8f"

  default_action {
    target_group_arn = "${aws_lb_target_group.chefserver.arn}"
    type             = "forward"
  }
}

resource "aws_lb_target_group_attachment" "chefserver" {
  target_group_arn = "${aws_lb_target_group.chefserver.arn}"
  target_id        = "${aws_instance.automate_cluster.*.id[1]}"
  port             = 8443
}

output "chefserver_url" {
  value = "https://${aws_lb.chefserver.dns_name}"
}
