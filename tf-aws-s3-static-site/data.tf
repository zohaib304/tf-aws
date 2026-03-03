data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "allow_cloudfront" {
  statement {
    sid    = "AllowCloudfrontOnly"
    effect = "Allow"

    # WHO can perform these actions?

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    # WHAT action are allowed to do?
    # s3:GetObject = download / read file from s3
    actions = ["s3:GetObject"]

    # ON WHAT? Every object inside you bucket
    resources = ["${aws_s3_bucket.site.arn}/*"]

    # CONDITION: only allow if the request came from OUR distribution.
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.site.arn]
    }
  }

}
