resource "random_pet" "lambda_bucket_name" {
  prefix = "learn-terraform-functions"
  length = 4
}

resource "aws_s3_bucket" "lambda_bucket" {
  bucket = random_pet.lambda_bucket_name.id
}

resource "aws_s3_bucket_acl" "bucket_acl" {
  bucket = aws_s3_bucket.lambda_bucket.id
  acl    = "private"
}

data "archive_file" "lambda_custom_search" {
  type = "zip"

  source_dir = "${path.module}/custom_search"
  output_path = "${path.module}/custom_search.zip"
}

resource "aws_s3_object" "lambda_custom_search" {
  bucket = aws_s3_bucket.lambda_bucket.id

  key = "custom_search.zip"
  source = data.archive_file.lambda_custom_search.output_path

  etag = filemd5(data.archive_file.lambda_custom_search.output_path)
}

resource "aws_lambda_function" "custom_search" {
  function_name = "CustomSearch"

  s3_bucket = aws_s3_bucket.lambda_bucket.id
  s3_key = aws_s3_object.lambda_custom_search.id

  runtime = "nodejs14.x"
  handler = "index.handler"

  source_code_hash = data.archive_file.lambda_custom_search.output_base64sha256

  role = aws_iam_role.lambda_exec.arn

  environment {
    variables = {
      CUSTOM_SEARCH_CX  = var.custom_search_cx
      CUSTOM_SEARCH_KEY = var.custom_search_key
    }
  }
}

resource "aws_cloudwatch_log_group" "custom_search" {
  name = "/aws/lambda/${aws_lambda_function.custom_search.function_name}"

  retention_in_days = 30
}

resource "aws_iam_role" "lambda_exec" {
  name = "serverless_lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Sid = ""
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

module "api_gateway" {
  source = "terraform-aws-modules/apigateway-v2/aws"

  name = "serverless_lambda_gw"
  protocol_type = "HTTP"
  create_api_domain_name = false
  cors_configuration = {
    allow_headers = ["content-type", "x-amz-date", "authorization", "x-api-key", "x-amz-security-token", "x-amz-user-agent"]
    allow_methods = ["*"]
    allow_origins = ["*"]
  }

  default_stage_access_log_destination_arn = aws_cloudwatch_log_group.api_gw.arn
  default_stage_access_log_format = jsonencode({
    requestId               = "$context.requestId"
    sourceIp                = "$context.identity.sourceIp"
    requestTime             = "$context.requestTime"
    protocol                = "$context.protocol"
    httpMethod              = "$context.httpMethod"
    resourcePath            = "$context.resourcePath"
    routeKey                = "$context.routeKey"
    status                  = "$context.status"
    responseLength          = "$context.responseLength"
    integrationErrorMessage = "$context.integrationErrorMessage"
  })

  integrations = {
    "GET /search" = {
      lambda_arn             = aws_lambda_function.custom_search.invoke_arn
      payload_format_version = "2.0"
      timeout_milliseconds   = 12000
    }
  }

  tags = {
    Name = "http-apigateway"
  }
}

resource "aws_cloudwatch_log_group" "api_gw" {
  name = "/aws/api_gw/access_log"

  retention_in_days = 30
}

resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.custom_search.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${module.api_gateway.apigatewayv2_api_execution_arn}/*/*"
}

# resource "aws_apigatewayv2_api" "lambda" {
#   name = "serverless_lambda_gw"
#   protocol_type = "HTTP"
# }

# resource "aws_apigatewayv2_stage" "lambda" {
#   api_id = aws_apigatewayv2_api.lambda.id

#   name = "serverless_lambda_stage"
#   auto_deploy = true
#   access_log_settings {
#     destination_arn = aws_cloudwatch_log_group.api_gw.arn

#     format = jsonencode({
#       requestId               = "$context.requestId"
#       sourceIp                = "$context.identity.sourceIp"
#       requestTime             = "$context.requestTime"
#       protocol                = "$context.protocol"
#       httpMethod              = "$context.httpMethod"
#       resourcePath            = "$context.resourcePath"
#       routeKey                = "$context.routeKey"
#       status                  = "$context.status"
#       responseLength          = "$context.responseLength"
#       integrationErrorMessage = "$context.integrationErrorMessage"
#     })
#   }
# }

# resource "aws_apigatewayv2_integration" "custom_search" {
#   api_id = aws_apigatewayv2_api.lambda.id

#   integration_uri    = aws_lambda_function.custom_search.invoke_arn
#   integration_type   = "AWS_PROXY"
#   integration_method = "POST"
# }

# resource "aws_apigatewayv2_route" "custom_search" {
#   api_id = aws_apigatewayv2_api.lambda.id

#   route_key = "GET /hello"
#   target    = "integrations/${aws_apigatewayv2_integration.custom_search.id}"
# }
