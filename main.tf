resource "aws_ecr_repository" "flask_app_ecr_registry" {
  name = "addressable"
}

data "aws_ecr_repository" "flask_app_ecr_registry" {
  name = "addressable"
  depends_on = [ 
    aws_ecr_repository.flask_app_ecr_registry
   ]
}

resource "aws_iam_role" "lambda_role" {
 name   = "aws_lambda_role"
 assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy" "iam_policy_for_lambda" {

  name         = "addressable-flask-lambda-function-policy"
  path         = "/"
  description  = "AWS IAM Policy for managing aws lambda role"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*",
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "attach_iam_policy_to_iam_role" {
  role        = aws_iam_role.lambda_role.name
  policy_arn  = aws_iam_policy.iam_policy_for_lambda.arn
}

resource "aws_lambda_function" "addressable_flask_lambda_function" {
 function_name = "addressable-flask-lambda-function"
 role          = aws_iam_role.lambda_role.arn
 image_uri     = "${data.aws_ecr_repository.flask_app_ecr_registry.repository_url}:0.0.1-test"
 package_type  = "Image"
 depends_on    = [aws_iam_role_policy_attachment.attach_iam_policy_to_iam_role]
}

resource "aws_lambda_permission" "addressable_flask_lambda_api_gateway" {
 statement_id  = "AllowAPIGatewayInvoke"
 action        = "lambda:InvokeFunction"
 function_name = aws_lambda_function.addressable_flask_lambda_function.function_name
 principal     = "apigateway.amazonaws.com"
 source_arn = "${aws_api_gateway_rest_api.api_gateway_flask_app.execution_arn}/*/*"
}

resource "aws_api_gateway_rest_api" "api_gateway_flask_app" {
  name        = "addressable-api-gateway-api"
  description = "API gateway for Flask app"
}

resource "aws_api_gateway_resource" "proxy" {
   rest_api_id = aws_api_gateway_rest_api.api_gateway_flask_app.id
   parent_id   = aws_api_gateway_rest_api.api_gateway_flask_app.root_resource_id
   path_part   = "{proxy+}"     # with proxy, this resource will match any request path
}

resource "aws_api_gateway_method" "proxy" {
   rest_api_id   = aws_api_gateway_rest_api.api_gateway_flask_app.id
   resource_id   = aws_api_gateway_resource.proxy.id
   http_method   = "ANY"       # with ANY, it allows any request method to be used, all incoming requests will match this resource
   authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda" {
   rest_api_id = aws_api_gateway_rest_api.api_gateway_flask_app.id
   resource_id = aws_api_gateway_method.proxy.resource_id
   http_method = aws_api_gateway_method.proxy.http_method
   integration_http_method = "POST"
   type                    = "AWS_PROXY"  # With AWS_PROXY, it causes API gateway to call into the API of another AWS service
   uri                     = aws_lambda_function.addressable_flask_lambda_function.invoke_arn
}

resource "aws_api_gateway_method" "proxy_root" {
   rest_api_id   = aws_api_gateway_rest_api.api_gateway_flask_app.id
   resource_id   = aws_api_gateway_rest_api.api_gateway_flask_app.root_resource_id
   http_method   = "ANY"
   authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_root" {
   rest_api_id = aws_api_gateway_rest_api.api_gateway_flask_app.id
   resource_id = aws_api_gateway_method.proxy_root.resource_id
   http_method = aws_api_gateway_method.proxy_root.http_method
   integration_http_method = "POST"
   type                    = "AWS_PROXY"
   uri                     = aws_lambda_function.addressable_flask_lambda_function.invoke_arn
}

resource "aws_api_gateway_deployment" "api_gateway_flask_app" {
   depends_on = [
     aws_api_gateway_integration.lambda,
     aws_api_gateway_integration.lambda_root,
   ]
   rest_api_id = aws_api_gateway_rest_api.api_gateway_flask_app.id
   stage_name  = "interview"
}

output "base_url" {
  value = aws_api_gateway_deployment.api_gateway_flask_app.invoke_url
}