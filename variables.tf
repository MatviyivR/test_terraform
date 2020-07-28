variable "backend_bucket" {
  default = "some_bucket_name"
}

variable "backend_dynamodb_table" {
  default = "some_backend_dynamodb_table"
}

variable "dynamodb_key" {
  default = "some/dynamodb_key"
}

variable "aws_region" {
  default = "us-east-1"
}

variable "project" {
  default = "test_project"
}

variable "env_name" {
  default = "test"
}


variable "vpc_name" {
  default = "Test_VPC"
}

variable "cidr_range" {
  type    = string
  default = "10.1.0.0/16"
}

variable "public_subnets" {
  default     = ["10.1.0.0/24", "10.1.1.0/24"]
  description = "CIDR blocks for public subnets"
  type        = list
}

variable "availability_zones" {
  default = {
    "us-east-1" = "us-east-1c,us-east-1d"
  }
}

variable "test_ips" {
  default = ["x.x.x.x/32", "x.x.x.x/x"]
}

variable "ami_id" {
  default = "some ami id"
}

data "aws_ssm_parameter" "test_ssh" {
  name = "/test_ssh/ssh"
}

variable "all_ips" {
  default = ["0.0.0.0/0"]
}

variable "cert_arn" {
  default = "some cert"
}
