
terraform {
  backend "s3" {
    encrypt        = true
    bucket         = var.backend_bucket
    dynamodb_table = var.backend_dynamodb_table
    key            = var.dynamodb_key
    region         = var.aws_region
  }
}





# Security_group for test instance

resource "aws_security_group" "test_instance" {
  name        = "${var.project}-${var.env_name}-sg"
  description = "Security Group for the ${var.project}-${var.env_name}"
  vpc_id      =

  tags = {
    Name       = "${var.project}-${var.env_name} Security Group"
    project    = var.project
    Automation = "Managed by Terraform"
  }
}

resource "aws_security_group_rule" "test_ingress_ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = var.test_ips
  security_group_id = aws_security_group.test_instance.id
}

resource "aws_security_group_rule" "test_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.test_instance.id
}


# Some instance

resource "aws_instance" "instance" {
  ami                         = var.ami_id
  instance_type               = "t2.micro"
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.test_instance.id]
  subnet_id                   = element(aws_subnet.test_public_subnet.*.id, count.index)
  key_name                    = "test_key"
  tags = {
    Name       = "${var.project}-${var.env_name}"
    project    = var.project
    Automation = "Managed by Terraform"
  }
}
resource "aws_key_pair" "key_pair" {
  key_name   = "test_key"
  public_key = data.aws_ssm_parameter.test_ssh.value
}

### attach elastic ip
resource "aws_eip" "test_instance_eip" {
  instance = "${aws_instance.instance.id}"
  vpc      = true
}

#### LB creation

resource "aws_security_group" "lb_sg" {
  name        = "${var.project}-ELB-sg"
  description = "Security Group for the ${var.project}-ELB"
  vpc_id      =

  tags = {
    Name       = "${var.project}-ELB Security Group"
    project    = var.project
    Automation = "Managed by Terraform"
  }
}

resource "aws_security_group_rule" "lb_ingress_80" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = var.all_ips
  security_group_id = aws_security_group.lb_sg.id
}

resource "aws_security_group_rule" "lb_ingress_443" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = var.all_ips
  security_group_id = aws_security_group.lb_sg.id
}

resource "aws_security_group_rule" "lb_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.lb_sg.id
}


resource "aws_lb" "test_elb" {
  name               = "${var.project}-ELB"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["${aws_security_group.lb_sg.id}"]
  subnets            = ["${aws_subnet.test_public_subnet.*.id}"]

  enable_deletion_protection = true

  tags = {
    Name       = "${var.project}-ELB"
    project    = var.project
    Automation = "Managed by Terraform"
  }
}

resource "aws_lb_listener" "test_redirect" {
  load_balancer_arn = aws_lb.test_elb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "test_forward" {
  load_balancer_arn = aws_lb.test_elb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.cert_arn

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/html"
      message_body = <<EOT
      <!DOCTYPE html>
      <html><head>
      <meta http-equiv="content-type" content="text/html; charset=UTF-8">
              <title>Server Error</title>
          </head>
          <body>
              <p>Server Error</p>
      </body></html>
EOT
      status_code  = "503"
    }
  }
}

resource "aws_lb_target_group" "test_instance_tg" {
  name        = "${var.project}-tg"
  port        = 80
  protocol    = "HTTPS"
  target_type = "instance"
  vpc_id      = aws_vpc.test_vpc.id

  health_check {
    path     = "/"
    protocol = "HTTP"
  }

  tags = {
    Name       = "${var.project}-tg"
    project    = var.project
    Automation = "Managed by Terraform"
  }
}

resource "aws_lb_target_group_attachment" "demo_integration" {
  target_group_arn = aws_lb_target_group.test_instance_tg.arn
  target_id        = aws_instance.instance.id
  port             = 80
}

resource "aws_security_group_rule" "elb-to-instance-traffic" {
  description              = "Allow elb go to demo1811 node"
  from_port                = 80
  protocol                 = "tcp"
  security_group_id        = aws.security_group.test_instance.id
  source_security_group_id = aws_security_group.lb_sg.id
  to_port                  = 80
  type                     = "ingress"
}
