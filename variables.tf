variable "aws_access_key" {
  description = "AWS access key"
}

variable "aws_secret_key" {
  description = "AWS secret key"
}

variable "region" {
  description = "AWS region"
  default     = "us-east-1"
}

variable "instance_count" {
  description = "Number of EC2 instances to create"
  default     = 3
}

variable "instance_type" {
  description = "EC2 instance type"
  default     = "t2.micro"
}

variable "domain_name" {
  description = "Domain name for Route 53"
  default     = "segunagoro.com"
}

