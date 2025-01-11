variable "instance_type" {
  type    = string
  default = "t2.medium"
}
variable "aws_region" {
  type    = string
  default = "us-east-1"
}
variable "key_name" {
  type    = string
  default = "ec2"
}
variable "ami" {
  type    = string
  default = "ami-0e2c8caa4b6378d8c"
}
