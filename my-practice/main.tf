# main.tf

provider "aws" {
  region = "us-east-1" # Change to your desired region
}

# Data source to get available availability zones
data "aws_availability_zones" "available" {}

# Create VPC
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = "MyVPC"
  }
}

# Create public and private subnets
resource "aws_subnet" "public_subnet" {
  count = 2
  vpc_id = aws_vpc.my_vpc.id
  cidr_block = element(["10.0.1.0/24", "10.0.2.0/24"], count.index)
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
  map_public_ip_on_launch = true
  tags = {
    Name = "Public_Subnet_${count.index + 1}"
  }
}

resource "aws_subnet" "private_subnet" {
  count = 2
  vpc_id = aws_vpc.my_vpc.id
  cidr_block = element(["10.0.3.0/24", "10.0.4.0/24"], count.index)
  availability_zone = element(data.aws_availability_zones.available.names, count.index)
  tags = {
    Name = "Private_Subnet_${count.index + 1}"
  }
}

# Create route tables
resource "aws_route_table" "public_route_table" {
  count = 2
  vpc_id = aws_vpc.my_vpc.id
  tags = {
    Name = "Public_Route_Table_${count.index + 1}"
  }
}

resource "aws_route_table" "private_route_table" {
  count = 2
  vpc_id = aws_vpc.my_vpc.id
  tags = {
    Name = "Private_Route_Table_${count.index + 1}"
  }
}

# Create security group
resource "aws_security_group" "web_sg" {
  vpc_id = aws_vpc.my_vpc.id
  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 80
    to_port   = 80
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 443
    to_port   = 443
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "Web_SG"
  }
}

# Create ELB
resource "aws_elb" "my_elb" {
  name               = "my-elb-proj"
  security_groups    = [aws_security_group.web_sg.id]
  availability_zones = aws_subnet.public_subnet[*].availability_zone
  listener {
      instance_port     = 8000
      instance_protocol = "http"
      lb_port           = 80
      lb_protocol       = "http"
    }

  health_check {
    target              = "HTTP:80/"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
  }
  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 443
    lb_protocol       = "https"
  }
}

# Create ALB
resource "aws_lb" "my_alb" {
  name               = "my-alb-proj"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web_sg.id]
  subnets            = aws_subnet.private_subnet[*].id
  enable_http2 = true
  enable_cross_zone_load_balancing = true

  enable_deletion_protection = false
}

# Create Route53 private hosted zone
resource "aws_route53_zone" "private_zone" {
  name          = "internal.mydomain.com"
  vpc {
    vpc_id = aws_vpc.my_vpc.id
  }
}

# Create CNAME entries for ALB and ELB
resource "aws_route53_record" "cname_alb" {
  zone_id = aws_route53_zone.private_zone.zone_id
  name    = "alb.internal.mydomain.com"
  type    = "CNAME"
  ttl     = "60"
  records = [aws_lb.my_alb.dns_name]
}

resource "aws_route53_record" "cname_elb" {
  zone_id = aws_route53_zone.private_zone.zone_id
  name    = "elb.internal.mydomain.com"
  type    = "CNAME"
  ttl     = "60"
  records = [aws_elb.my_elb.dns_name]
}

# Create S3 bucket
resource "aws_s3_bucket" "my_s3_bucket" {
  bucket = "my-unique-s3-bucket-name"
 }

# Create IAM policy for Assignment-3
resource "aws_iam_policy" "assignment_3_policy" {
  name        = "Assignment3Policy"
  description = "IAM Policy for Assignment-3"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": "${aws_s3_bucket.my_s3_bucket.arn}/*"
    }
  ]
}
EOF
}

# Create IAM role and attach the policy
resource "aws_iam_role" "assignment_3_role" {
  name = "Assignment3Role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "assignment_3_attachment" {
  policy_arn = aws_iam_policy.assignment_3_policy.arn
  role       = aws_iam_role.assignment_3_role.name
}

# Output variables
output "vpc_id" {
  value = aws_vpc.my_vpc.id
}

output "public_subnet_ids" {
  value = aws_subnet.public_subnet[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private_subnet[*].id
}

output "web_sg_id" {
  value = aws_security_group.web_sg.id
}

output "elb_dns_name" {
  value = aws_elb.my_elb.dns_name
}

