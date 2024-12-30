# Provider Configuration
provider "aws" {
  region = "us-east-1" # Change to your preferred region
}

# Variables (Define these only if not already defined elsewhere)
# Uncomment if necessary and not already declared in another file
# variable "ami_id" {
#   default = "ami-0c55b159cbfafe1f0" # Replace with your AMI ID
# }
# variable "instance_type" {
#   default = "t2.micro" # Replace with your desired instance type
# }

# Data Source: Check if S3 Bucket Exists
data "aws_s3_bucket" "existing_bucket" {
  bucket = "my-unique-bucket-name-1989"
}

# S3 Bucket for Website Hosting
resource "aws_s3_bucket" "my_bucket" {
  count  = length(data.aws_s3_bucket.existing_bucket.id) == 0 ? 1 : 0
  bucket = "my-unique-bucket-name-1989" # Replace with a globally unique bucket name
}

# S3 Bucket ACL
resource "aws_s3_bucket_acl" "my_bucket_acl" {
  bucket = aws_s3_bucket.my_bucket[0].id
  acl    = "private" # Use "private" ACL to avoid conflicts
}

# S3 Bucket Website Configuration
resource "aws_s3_bucket_website_configuration" "my_bucket_website" {
  bucket = aws_s3_bucket.my_bucket[0].id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

# Public Access Block for the S3 Bucket
resource "aws_s3_bucket_public_access_block" "my_bucket_public_access" {
  bucket = aws_s3_bucket.my_bucket[0].id

  block_public_acls   = false  # Allow public ACLs
  ignore_public_acls  = false  # Don't ignore public ACLs
  block_public_policy = false  # Allow public policies
}

# S3 Bucket Policy for Public Read Access
resource "aws_s3_bucket_policy" "my_bucket_policy" {
  bucket = aws_s3_bucket.my_bucket[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "s3:GetObject"
        Effect    = "Allow"
        Resource  = "${aws_s3_bucket.my_bucket[0].arn}/*"
        Principal = "*"
      }
    ]
  })
}

# Data Source: Check if Security Group Exists
data "aws_security_group" "existing_sg" {
  filter {
    name   = "group-name"
    values = ["ec2-sg-unique"]
  }

  vpc_id = "vpc-006993ee517a74e91" # Replace with your VPC ID
}

# Security Group for EC2 Instance
resource "aws_security_group" "ec2_sg" {
  count       = length(data.aws_security_group.existing_sg.id) == 0 ? 1 : 0
  name        = "ec2-sg-unique"
  description = "Allow SSH and HTTP traffic"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow SSH from anywhere, restrict for production
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow HTTP traffic from anywhere
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC2 Instance (using Security Group)
resource "aws_instance" "my_instance" {
  ami           = "ami-0c55b159cbfafe1f0" # Replace with your AMI ID
  instance_type = "t2.micro"              # Replace with your desired instance type
  security_groups = [aws_security_group.ec2_sg[0].name]

  tags = {
    Name = "Terraform-EC2"
  }
}

# CloudFront Distribution (dependent on S3 Bucket)
resource "aws_cloudfront_distribution" "my_distribution" {
  origin {
    domain_name = aws_s3_bucket.my_bucket[0].bucket_regional_domain_name
    origin_id   = "s3-origin"
  }

  enabled             = true
  default_root_object = "index.html"

  default_cache_behavior {
    target_origin_id       = "s3-origin"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Name = "CloudFrontDistribution"
  }
}

# Output S3 Bucket Name
output "s3_bucket_name" {
  value = aws_s3_bucket.my_bucket[0].id
}
