resource "aws_s3_bucket" "static_site" {
  bucket = var.bucket_name
}

# resource "aws_s3_bucket_website_configuration" "static_site_config" {
#   bucket = aws_s3_bucket.static_site.id
#   index_document {
#     suffix = "index.html"
#   }
# }

resource "aws_s3_bucket_public_access_block" "static_site_access" {
  bucket                  = aws_s3_bucket.static_site.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# resource "aws_s3_bucket_policy" "static_site_policy" {
#   depends_on = [ aws_s3_bucket_public_access_block.static_site_access ]
#   bucket = aws_s3_bucket.static_site.id
#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Principal = "*"
#         Action = "s3:GetObject"
#         Resource = "${ aws_s3_bucket.static_site.arn }/*"
#       }
#     ]
#   })  
# }


resource "aws_cloudfront_origin_access_control" "website" {
  name = "website-oac"
  description = "OAC for website"
  origin_access_control_origin_type = "s3"
  signing_behavior = "always"
  signing_protocol = "sigv4"
}

resource "aws_cloudfront_distribution" "website" {
  enabled = true
  default_root_object = "index.html"

  origin {
    domain_name = aws_s3_bucket.static_site.bucket_regional_domain_name
    origin_id = "website-origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.website.id    
  }

  default_cache_behavior {
    target_origin_id = "website-origin"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET", "HEAD"]
    cached_methods = ["GET", "HEAD"]
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }  

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

data "aws_iam_policy_document" "cloudfront_access" {

  statement {

    actions = [
      "s3:GetObject"
    ]

    resources = [
      "${aws_s3_bucket.static_site.arn}/*"
    ]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"

      values = [
        aws_cloudfront_distribution.website.arn
      ]
    }
  }
}

resource "aws_s3_bucket_policy" "website" {
  bucket = aws_s3_bucket.static_site.id
  policy = data.aws_iam_policy_document.cloudfront_access.json
}

output "cloudfront_url" {
  value = aws_cloudfront_distribution.website.domain_name
}