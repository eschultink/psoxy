terraform {
  required_providers {
    # for the infra that will host Psoxy instances
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.12"
    }
  }
}

module "psoxy-aws" {
  source = "../aws"

  caller_aws_account_id   = var.caller_aws_account_id
  caller_external_user_id = var.caller_external_user_id
  aws_account_id          = var.aws_account_id
}


module "psoxy-package" {
  source = "../psoxy-package"

  implementation     = "aws"
  path_to_psoxy_java = "${var.psoxy_base_dir}/java"
}

## START HRIS MODULE - COPY TO YOUR MASTER main.tf

resource "aws_s3_bucket" "input" {
  bucket = "psoxy-${var.instance_id}-input"
}

/*
 * USE CASE: By default config as is works. But customer attached own rules to bucket, that seems to
 * supersede default, so this piece needs to be added to the bucket policies too.

locals {
  // this should come as variable, but being optional not done for now
  hris_lambda_execution_role_arn = "arn:aws:iam::${var.aws_account_id}:role/iam_for_lambda_psoxy-hris"
  read_policy_json = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid": "GrantLambdaAccessToInputBucket",
        "Action": [
          "s3:GetObject"
        ],
        "Effect": "Allow",
        "Resource": [
          "${aws_s3_bucket.input.arn}/*"
        ],
        "Principal": {
          "AWS": [
            "${local.hris_lambda_execution_role_arn}"
          ]
        }
      }
    ]
  })
}

resource "aws_s3_bucket_policy" "read_policy_to_execution_role" {
  bucket = aws_s3_bucket.input
  policy = local.read_policy_json
}

*/

resource "aws_iam_policy" "read_policy_to_execution_role" {
  name        = "BucketRead_${aws_s3_bucket.input.id}"
  description = "Allow principal to read from input bucket: ${aws_s3_bucket.input.id}"

  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Sid" : "GrantLambdaAccessToInputBucket",
          "Action" : [
            "s3:GetObject"
          ],
          "Effect" : "Allow",
          "Resource" : [
            "${aws_s3_bucket.input.arn}/*"
          ],
          "Principal" : {
            "AWS" : [
              "${local.hris_lambda_execution_role_arn}"
            ]
          }
        }
      ]
  })
}


resource "aws_s3_bucket" "output" {
  bucket = "psoxy-${var.instance_id}-output"
}

module "psoxy-file-handler" {
  source = "../aws-psoxy-instance"

  function_name        = "psoxy-${var.instance_id}"
  handler_class        = "co.worklytics.psoxy.S3Handler"
  source_kind          = var.source_kind
  path_to_function_zip = module.psoxy-package.path_to_deployment_jar
  function_zip_hash    = module.psoxy-package.deployment_package_hash
  path_to_config       = "${var.psoxy_base_dir}/configs/${var.source_kind}.yaml"
  aws_assume_role_arn  = var.aws_assume_role_arn
  example_api_calls    = [] #None, as this function is called through the S3 event
  aws_account_id       = var.aws_account_id

  parameters = []

  environment_variables = {
    INPUT_BUCKET  = aws_s3_bucket.input.bucket,
    OUTPUT_BUCKET = aws_s3_bucket.output.bucket
  }
}

resource "aws_lambda_permission" "allow_input_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = module.psoxy-file-handler.function_arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.input.arn
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.input.id

  lambda_function {
    lambda_function_arn = module.psoxy-file-handler.function_arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.allow_input_bucket]
}

resource "aws_iam_policy" "input_bucket_read_policy" {
  name        = "BucketRead_${aws_s3_bucket.input.id}"
  description = "Allow principal to read from input bucket: ${aws_s3_bucket.input.id}"

  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Action" : [
            "s3:GetObject"
          ],
          "Effect" : "Allow",
          "Resource" : "${aws_s3_bucket.input.arn}/*"
        }
      ]
  })
}

resource "aws_iam_role_policy_attachment" "read_policy_for_import_bucket" {
  role       = module.psoxy-file-handler.iam_for_lambda_name
  policy_arn = aws_iam_policy.input_bucket_read_policy.arn
}

resource "aws_iam_policy" "output_bucket_write_policy" {
  name        = "BucketWrite_${aws_s3_bucket.output.id}"
  description = "Allow principal to write to bucket: ${aws_s3_bucket.output.id}"

  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Action" : [
            "s3:PutObject",
          ],
          "Effect" : "Allow",
          "Resource" : "${aws_s3_bucket.output.arn}/*"
        }
      ]
  })
}

resource "aws_iam_role_policy_attachment" "write_policy_for_output_bucket" {
  role       = module.psoxy-file-handler.iam_for_lambda_name
  policy_arn = aws_iam_policy.output_bucket_write_policy.arn
}

resource "aws_iam_policy" "output_bucket_read" {
  name        = "BucketRead_${aws_s3_bucket.output.id}"
  description = "Allow to read content from bucket: ${aws_s3_bucket.output.id}"

  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Action" : [
            "s3:GetObject",
            "s3:ListBucket"
          ],
          "Effect" : "Allow",
          "Resource" : [
            "${aws_s3_bucket.output.arn}",
            "${aws_s3_bucket.output.arn}/*"
          ]
        }
      ]
  })
}

resource "aws_iam_role_policy_attachment" "caller_bucket_access_policy" {
  role       = module.psoxy-aws.api_caller_role_name
  policy_arn = aws_iam_policy.output_bucket_read.arn
}

## END HRIS MODULE
