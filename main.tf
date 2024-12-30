provider "aws" {
  region = "us-east-1" # Change to your preferred region
}

# Generate a random suffix for uniqueness
resource "random_id" "bucket_id" {
  byte_length = 8
}

resource "random_id" "sg_id" {
  byte_length = 8
}

# Check if the S3 Bucket already exists (using data source)
data "aws_s3_bucket" "my_existing_bucket" {
  bucket = "my-unique-bucket-name-${random_id.bucket_id.hex}"
}

# Check if the Security Group already exists (using data source)
data "aws_security_group" "my_existing_sg" {
  name = "ec2-sg-unique-${random_id.sg_id.hex}"
}

# Conditionally create S3 Bucket if not already existing
resource "aws_s3_bucket" "my_bucket" {
  count  = length(data.aws_s3_bucket.my_existing_bucket.id) == 0 ? 1 : 0
  bucket = "my-unique-bucket-name-${random_id.bucket_id.hex}" # Ensure unique name
}

# S3 Bucket ACL (to replace deprecated 'acl' argument)
resource "aws_s3_bucket_acl" "my_bucket_acl" {
  count  = length(data.aws_s3_bucket.my_existing_bucket.id) == 0 ? 1 : 0
  bucket = aws_s3_bucket.my_bucket[count.index].id
  acl    = "private"
}

# S3 Bucket Website Configuration
resource "aws_s3_bucket_website_configuration" "my_bucket_website" {
  count  = length(data.aws_s3_bucket.my_existing_bucket.id) == 0 ? 1 : 0
  bucket = aws_s3_bucket.my_bucket[count.index].id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

# Public Access Block for the S3 Bucket
resource "aws_s3_bucket_public_access_block" "my_bucket_public_access" {
  count  = length(data.aws_s3_bucket.my_existing_bucket.id) == 0 ? 1 : 0
  bucket = aws_s3_bucket.my_bucket[count.index].id

  block_public_acls   = false  # Allow public ACLs
  ignore_public_acls  = false  # Don't ignore public ACLs
  block_public_policy = false  # Allow public policies
}

# S3 Bucket Policy for Public Read Access
resource "aws_s3_bucket_policy" "my_bucket_policy" {
  count  = length(data.aws_s3_bucket.my_existing_bucket.id) == 0 ? 1 : 0
  bucket = aws_s3_bucket.my_bucket[count.index].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "s3:GetObject"
        Effect    = "Allow"
        Resource  = "${aws_s3_bucket.my_bucket[count.index].arn}/*"
        Principal = "*"
      }
    ]
  })
}

# CloudFront Distribution (dependent on S3 Bucket)
resource "aws_cloudfront_distribution" "my_distribution" {
  count = length(data.aws_s3_bucket.my_existing_bucket.id) == 0 ? 1 : 0

  origin {
    domain_name = aws_s3_bucket.my_bucket[count.index].bucket_regional_domain_name
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

# Security Group for EC2 Instance (ensure name is unique)
resource "aws_security_group" "ec2_sg" {
  count  = length(data.aws_security_group.my_existing_sg.id) == 0 ? 1 : 0
  name        = "ec2-sg-unique-${random_id.sg_id.hex}" # Ensure unique name
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
  count = length(data.aws_security_group.my_existing_sg.id) == 0 ? 1 : 0
  ami           = var.ami_id # Provide AMI ID via variables
  instance_type = var.instance_type # Provide instance type via variables
  security_groups = [aws_security_group.ec2_sg[count.index].name]

  tags = {
    Name = "Terraform-EC2"
  }
}
