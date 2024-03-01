terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-east-1"
  profile = "sso-dev"
}


# Create a VPC
resource "aws_vpc" "myfirstvpc" {
  cidr_block = "10.0.0.0/16"
}

#Create a subnet
resource "aws_subnet" "myfirstsubnet" {
  vpc_id     = aws_vpc.myfirstvpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "first"
  }
}
#internet gateway
resource "aws_internet_gateway" "myfirstgateway" {
  vpc_id = aws_vpc.myfirstvpc.id

  tags = {
    Name = "first"
  }
}

#associate route table to subnet
resource "aws_route_table_association" "a" {
  subnet_id = aws_subnet.myfirstsubnet.id
  route_table_id = aws_route_table.myfirstroutettable.id
}

#ec2 instance security group
resource "aws_security_group" "allow" {
  name        = "allow"
  description = "Allow inbound traffic"
  vpc_id      = aws_vpc.myfirstvpc.id

  ingress {
    description = "ssh from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_ssh"
  }
}

#network interface
resource "aws_network_interface" "foo" {
  subnet_id   = aws_subnet.myfirstsubnet.id
  private_ips = ["10.0.1.100"]
  security_groups = [aws_security_group.allow.id]


}


#route table
resource "aws_route_table" "myfirstroutettable" {
  vpc_id = aws_vpc.myfirstvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.myfirstgateway.id
  }

  tags = {
    Name = "first"
  }
}


#elastic ip
resource "aws_eip" "firsteip" {
  vpc = true
  network_interface = aws_network_interface.foo.id
  associate_with_private_ip = "10.0.1.100"
  depends_on = [ aws_internet_gateway.myfirstgateway ]
}

#iam role github actions
data "aws_iam_policy_document" "github_actions_assume_role" {
    statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "github_actions_role" {
  name = "github-actions-role"
  path = "/system/"
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json
}

resource "aws_iam_role_policy_attachment" "github_actions_s3_sync" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
  role       = aws_iam_role.github_actions_role.name
}

#request certificate
resource "aws_acm_certificate" "cert" {
  domain_name       = "horizontech.cloud"
  validation_method = "DNS"

  tags = {
    Environment = "static site"
  }

  lifecycle {
    create_before_destroy = true
  }
}

#S3 Host Subdomain
resource "aws_s3_bucket" "staticwebsite" {

  tags = {
    Name        = "Website"
    Environment = "Dev"
  }
}

#S3 Host Root Domain