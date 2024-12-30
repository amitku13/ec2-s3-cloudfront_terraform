provider "aws" {
  region = "us-east-1"  # Corrected region to us-east-1
}

resource "aws_s3_bucket" "my_bucket" {
  bucket = "my-unique-bucket-name"
  acl    = "private"  # Private ACL to avoid conflicts
}

resource "aws_security_group" "ec2_sg" {
  name        = "ec2-sg-unique"
  description = "Security group for EC2 instances"
  vpc_id      = "vpc-006993ee517a74e91"
}

resource "aws_instance" "my_instance" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"
  security_groups = [aws_security_group.ec2_sg.name]
}

resource "aws_cloudfront_distribution" "my_distribution" {
  origin {
    domain_name = aws_s3_bucket.my_bucket.bucket_regional_domain_name
    origin_id   = "S3-origin"
  }
  enabled = true
}

output "s3_bucket_name" {
  value = aws_s3_bucket.my_bucket.id
}

output "ec2_instance_public_ip" {
  value = aws_instance.my_instance.public_ip
}

output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.my_distribution.domain_name
}
