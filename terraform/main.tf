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
  acm_certificate_arn      = aws_acm_certificate_validation.website.certificate_arn
  ssl_support_method       = "sni-only"
  minimum_protocol_version = "TLSv1.2_2021"
}

  aliases = [
  "tanzeelalam.co.in",
  "www.tanzeelalam.co.in"
]
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

data "aws_route53_zone" "website" {
  name         = "tanzeelalam.co.in"
  private_zone = false
}

resource "aws_acm_certificate" "website" {
  provider = aws.virginia

  domain_name               = "tanzeelalam.co.in"
  subject_alternative_names = ["www.tanzeelalam.co.in"]

  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.website.domain_validation_options :
    dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  zone_id         = data.aws_route53_zone.website.zone_id

  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.record]
}

resource "aws_acm_certificate_validation" "website" {
  provider = aws.virginia

  certificate_arn = aws_acm_certificate.website.arn

  validation_record_fqdns = [
    for record in aws_route53_record.cert_validation :
    record.fqdn
  ]
}

resource "aws_route53_record" "root" {
  zone_id = data.aws_route53_zone.website.zone_id

  name = "tanzeelalam.co.in"
  type = "A"

  alias {
    name                   = aws_cloudfront_distribution.website.domain_name
    zone_id                = aws_cloudfront_distribution.website.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "www" {
  zone_id = data.aws_route53_zone.website.zone_id

  name = "www"
  type = "A"

  alias {
    name                   = aws_cloudfront_distribution.website.domain_name
    zone_id                = aws_cloudfront_distribution.website.hosted_zone_id
    evaluate_target_health = false
  }
}