output "s3_bucket_name" {
  value = aws_s3_bucket.my_bucket[count.index].id
}

output "ec2_instance_public_ip" {
  value = aws_instance.my_instance[count.index].public_ip
}

output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.my_distribution[count.index].domain_name
}
