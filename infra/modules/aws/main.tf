# setup AWS project to host Psoxy instances

terraform {
  required_providers {
    aws = {
      version = "~> 4.12"
    }
  }
}

# role that Worklytics user will use to call the API
resource "aws_iam_role" "api-caller" {
  name = "PsoxyApiCaller"

  # who can assume this role
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : "sts:AssumeRole",
        "Principal" : {
          "Service" : "lambda.amazonaws.com"
        },
        "Effect" : "Allow",
        "Sid" : ""
      },
      {
        "Action" = "sts:AssumeRole"
        "Effect" : "Allow"
        "Principal" : {
          "AWS" : "arn:aws:iam::${var.caller_aws_account_id}"
        }
      },
      # allows service account to assume role
      {
        "Effect" : "Allow",
        "Principal" : {
          "Federated" : "accounts.google.com"
        },
        "Action" : "sts:AssumeRoleWithWebIdentity",
        "Condition" : {
          "StringEquals" : {
            "accounts.google.com:aud" : var.caller_external_user_id
          }
        }
      }
    ]
  })
}

# Allow caller to read parameters required by lambdas
resource "aws_iam_policy" "read_parameters_policy" {
  name        = "ssmGetParameters"
  description = "Allow lambda function role to read SSM parameters"

  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Action" : [
            "ssm:GetParameter*"
          ],
          "Effect" : "Allow",
          "Resource" : "arn:aws:ssm:${var.region}:${var.aws_account_id}:parameter/*"
        }
      ]
  })
}

resource "aws_iam_role_policy_attachment" "read_parameters_policy_attach" {
  role       = aws_iam_role.api-caller.name
  policy_arn = aws_iam_policy.read_parameters_policy.arn
}


resource "aws_iam_policy" "execution_lambda_to_caller" {
  name        = "ExecutePsoxyLambdas"
  description = "Allow caller role to execute the lambda url directly"

  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Action" : ["lambda:InvokeFunctionUrl"],
          "Effect" : "Allow",
          "Resource" : "arn:aws:lambda:${var.region}:${var.aws_account_id}:function:psoxy-*"
        }
      ]
  })
}

resource "aws_iam_role_policy_attachment" "invoker_lambda_execution" {
  role       = aws_iam_role.api-caller.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "invoker_url_lambda_execution" {
  role       = aws_iam_role.api-caller.name
  policy_arn = aws_iam_policy.execution_lambda_to_caller.arn
}


# not really a 'password', but 'random_string' isn't "sensitive" by terraform, so
# is output to console
resource "random_password" "random" {
  length  = 20
  special = true
}

# initial random salt to use; if you DON'T want this in your Terraform state, create a new version
# via some other means (eg, directly in GCP console). this should be done BEFORE your psoxy
# instance pseudonymizes anything; if salt is changed later, pseudonymization output will differ so
# previously pseudonymized data will be inconsistent with data pseudonymized after the change.
#
# To be clear, possession of salt alone doesn't let someone reverse pseudonyms.
resource "aws_ssm_parameter" "salt" {
  name        = "PSOXY_SALT"
  type        = "SecureString"
  description = "Salt used to build pseudonyms"
  value       = sensitive(random_password.random.result)

  lifecycle {
    ignore_changes = [
      value
    ]
  }
}

output "salt_secret" {
  value = aws_ssm_parameter.salt
}

output "api_caller_role_arn" {
  value = aws_iam_role.api-caller.arn
}

output "api_caller_role_name" {
  value = aws_iam_role.api-caller.name
}
