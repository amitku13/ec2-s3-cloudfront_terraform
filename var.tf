# Variables for EC2
variable "ami_id" {
  default = "ami-01816d07b1128cd2d" # Change to a valid AMI ID in your region
}

variable "instance_type" {
  default = "t2.micro"
}
