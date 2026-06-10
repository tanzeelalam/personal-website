resource "aws-s3-bucket" "personal-website-bucket" {
  bucket = var.website_bucket_name
}