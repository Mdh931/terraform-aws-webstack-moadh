locals {
  name = "${var.project}-${var.environment}"
}

# Security Group de l'ALB : ouvert en HTTP sur Internet, ne parle qu'aux instances
resource "aws_security_group" "alb" {
  name        = "${local.name}-alb"
  description = "ALB ${local.name}"
  vpc_id      = var.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_web" {
  security_group_id            = aws_security_group.alb.id
  referenced_security_group_id = aws_security_group.web.id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
}

# Security Group des instances : HTTP uniquement depuis l'ALB, aucun SSH
resource "aws_security_group" "web" {
  name        = "${local.name}-web"
  description = "Instances web ${local.name}"
  vpc_id      = var.vpc_id

  # Règles en ligne : Terraform gère le Security Group en entier,
  # une règle ajoutée à la main apparaît comme une dérive au plan
  ingress {
    description     = "HTTP depuis l'ALB uniquement"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Sortie vers Internet (paquets, Parameter Store)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_launch_template" "web" {
  name_prefix            = "${local.name}-"
  image_id               = var.ami_id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.web.id]
  update_default_version = true

  iam_instance_profile {
    name = var.instance_profile_name
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  monitoring {
    enabled = true
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 8
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  user_data = base64encode(templatefile("${path.module}/bootstrap.sh", {
    project               = var.project
    environment           = var.environment
    region                = var.region
    secret_parameter_name = var.secret_parameter_name
    app_message           = var.app_message
  }))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${local.name}-web"
    }
  }
}

resource "aws_lb" "web" {
  name                       = "${local.name}-alb"
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.alb.id]
  subnets                    = var.subnet_ids
  drop_invalid_header_fields = true
}

resource "aws_lb_target_group" "web" {
  name                 = "${local.name}-tg"
  port                 = 80
  protocol             = "HTTP"
  vpc_id               = var.vpc_id
  deregistration_delay = 30

  health_check {
    path                = "/"
    matcher             = "200"
    interval            = 15
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.web.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

resource "aws_autoscaling_group" "web" {
  name                      = "${local.name}-asg-v${aws_launch_template.web.latest_version}"
  min_size                  = var.min_size
  max_size                  = var.max_size
  desired_capacity          = var.desired_capacity
  vpc_zone_identifier       = var.subnet_ids
  health_check_type         = "ELB"
  health_check_grace_period = 180
  target_group_arns         = [aws_lb_target_group.web.arn]
  wait_for_elb_capacity     = var.min_size

  launch_template {
    id      = aws_launch_template.web.id
    version = aws_launch_template.web.latest_version
  }


  lifecycle {
    create_before_destroy = true
  }

  tag {
    key                 = "Name"
    value               = "${local.name}-web"
    propagate_at_launch = true
  }
}
