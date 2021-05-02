##############
## Provider ##
##############

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.27"
    }
  }

  required_version = ">= 0.14.9"
}

provider "aws" {
  profile = "default"
  region  = var.region
}


#########################
## Domain, certificate ##
#########################

data "aws_route53_zone" "selected" {
  name = var.hosted_zone_name
}

resource "aws_route53_record" "lab-record-tf" {
  zone_id         = data.aws_route53_zone.selected.zone_id
  name            = var.domain_name
  type            = "A"
  allow_overwrite = true

  alias {
    name                   = aws_lb.lab-lb-tf.dns_name
    zone_id                = aws_lb.lab-lb-tf.zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "lab-cert-validation-record-tf" {
  for_each = {
    for dvo in aws_acm_certificate.lab-lb-cert-tf.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.selected.zone_id
}

resource "aws_acm_certificate_validation" "lab-cert-validation-tf" {
  certificate_arn         = aws_acm_certificate.lab-lb-cert-tf.arn
  validation_record_fqdns = [ for record in aws_route53_record.lab-cert-validation-record-tf : record.fqdn ]
}

resource "aws_acm_certificate" "lab-lb-cert-tf" {
  domain_name       = var.domain_name
  validation_method = "DNS"
}


###################
## Load balancer ##
###################

data "aws_subnet_ids" "available" {
  vpc_id = var.vpc_id
}

resource "aws_lb" "lab-lb-tf" {
  name               = "lab-lb-tf"
  internal           = false
  load_balancer_type = "application"
  ip_address_type    = "ipv4"
  subnets            = data.aws_subnet_ids.available.ids
  security_groups    = [ aws_security_group.lab-lb-sg-tf.id ]
}

resource "aws_security_group" "lab-lb-sg-tf" {
  name   = "lab-lb-sg-tf"
  description = "Allow HTTP and HTTPS inbound traffic"
  vpc_id = var.vpc_id

  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_lb_target_group" "lab-tg-tf" {
  name        = "lab-tg-tf"
  port        = var.hub_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    interval            = 30
    path                = "/hub/login?next=%2Fhub%2F"
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
    matcher             = "200-299"
  }

  stickiness {
    cookie_duration = 86400
    enabled         = true
    type            = "lb_cookie"
  }
}

resource "aws_lb_listener" "lab-lb-http-listener-tf" {
  load_balancer_arn = aws_lb.lab-lb-tf.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = 443
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "lab-lb-https-listener-tf" {
  load_balancer_arn = aws_lb.lab-lb-tf.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.lab-lb-cert-tf.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lab-tg-tf.arn
  }
}


##################
## Auto-scaling ##
##################

resource "aws_launch_template" "lab-lt-tf" {
  name                   = "lab-lt-tf"
  image_id               = var.image_id
  instance_type          = var.instance_type
  vpc_security_group_ids = [ aws_security_group.lab-instance-sg-tf.id ]

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "Lab"
    }
  }
}

resource "aws_security_group" "lab-instance-sg-tf" {
  name   = "lab-instance-sg-tf"
  description = "Allow connections from Load Balancer"
  vpc_id = var.vpc_id

  ingress {
    description      = "HTTP"
    from_port        = var.hub_port
    to_port          = var.hub_port
    protocol         = "tcp"
    security_groups  = [ aws_security_group.lab-lb-sg-tf.id ]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

data "aws_availability_zones" "available" {}

resource "aws_autoscaling_group" "lab-asg-tf" {
  name                    = "lab-asg-tf"

  availability_zones      = data.aws_availability_zones.available.names

  target_group_arns       = [ aws_lb_target_group.lab-tg-tf.arn ]

  min_size                = var.asg_min
  max_size                = var.asg_max
  desired_capacity        = var.asg_desired

  health_check_type       = "ELB"

  launch_template {
    id      = aws_launch_template.lab-lt-tf.id
    version = "$Latest"
  }
}
