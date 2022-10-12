provider "aws" {
}

resource "random_id" "id" {
  byte_length = 8
}

resource "aws_iam_role" "appsync" {
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "appsync.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

data "aws_iam_policy_document" "appsync" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "arn:aws:logs:*:*:*"
    ]
  }
  
  statement {
    actions = [
      "dynamodb:Scan",
    ]
    resources = [
      aws_dynamodb_table.user.arn,
      aws_dynamodb_table.document.arn,
      aws_dynamodb_table.file.arn,
    ]
  }
}

resource "aws_iam_role_policy" "appsync_logs" {
  role   = aws_iam_role.appsync.id
  policy = data.aws_iam_policy_document.appsync.json
}

resource "aws_appsync_graphql_api" "appsync" {
  name                = "appsync_test"
  schema              = file("schema.graphql")
  authentication_type = "AWS_IAM"
  log_config {
    cloudwatch_logs_role_arn = aws_iam_role.appsync.arn
    field_log_level          = "ALL"
  }
}

resource "aws_cloudwatch_log_group" "loggroup" {
  name              = "/aws/appsync/apis/${aws_appsync_graphql_api.appsync.id}"
  retention_in_days = 14
}

resource "aws_dynamodb_table" "user" {
  name         = "user-${random_id.id.hex}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

resource "aws_dynamodb_table_item" "user1" {
  table_name = aws_dynamodb_table.user.name
  hash_key   = aws_dynamodb_table.user.hash_key

  item = <<ITEM
{
  "id": {"S": "user1"},
	"type": {"S": "user"}
}
ITEM
}

resource "aws_dynamodb_table_item" "user2" {
  table_name = aws_dynamodb_table.user.name
  hash_key   = aws_dynamodb_table.user.hash_key

  item = <<ITEM
{
  "id": {"S": "user2"},
	"type": {"S": "user"}
}
ITEM
}

resource "aws_dynamodb_table_item" "admin1" {
  table_name = aws_dynamodb_table.user.name
  hash_key   = aws_dynamodb_table.user.hash_key

  item = <<ITEM
{
  "id": {"S": "user3"},
	"type": {"S": "admin"},
	"permissions": {"SS": ["create-users"]}
}
ITEM
}

resource "aws_appsync_datasource" "ddb_users" {
  api_id           = aws_appsync_graphql_api.appsync.id
  name             = "ddb_users"
  service_role_arn = aws_iam_role.appsync.arn
  type             = "AMAZON_DYNAMODB"
  dynamodb_config {
    table_name = aws_dynamodb_table.user.name
  }
}

resource "aws_dynamodb_table" "document" {
  name         = "document-${random_id.id.hex}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

resource "aws_dynamodb_table_item" "doc1" {
  table_name = aws_dynamodb_table.document.name
  hash_key   = aws_dynamodb_table.document.hash_key

  item = <<ITEM
{
  "id": {"S": "doc1"},
	"contents": {"S": "important document"}
}
ITEM
}

resource "aws_dynamodb_table_item" "doc2" {
  table_name = aws_dynamodb_table.document.name
  hash_key   = aws_dynamodb_table.document.hash_key

  item = <<ITEM
{
  "id": {"S": "doc2"},
	"contents": {"S": "super important document"}
}
ITEM
}

resource "aws_appsync_datasource" "ddb_documents" {
  api_id           = aws_appsync_graphql_api.appsync.id
  name             = "ddb_documents"
  service_role_arn = aws_iam_role.appsync.arn
  type             = "AMAZON_DYNAMODB"
  dynamodb_config {
    table_name = aws_dynamodb_table.document.name
  }
}

resource "aws_dynamodb_table" "file" {
  name         = "file-${random_id.id.hex}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

resource "aws_dynamodb_table_item" "file1" {
  table_name = aws_dynamodb_table.file.name
  hash_key   = aws_dynamodb_table.file.hash_key

  item = <<ITEM
{
  "id": {"S": "file1"},
	"filename": {"S": "schemas.pdf"},
	"url": {"S": "example.com/schemas.pdf"}
}
ITEM
}

resource "aws_appsync_datasource" "ddb_files" {
  api_id           = aws_appsync_graphql_api.appsync.id
  name             = "ddb_files"
  service_role_arn = aws_iam_role.appsync.arn
  type             = "AMAZON_DYNAMODB"
  dynamodb_config {
    table_name = aws_dynamodb_table.file.name
  }
}

resource "aws_appsync_resolver" "Query_listUsers" {
  api_id            = aws_appsync_graphql_api.appsync.id
  type              = "Query"
  field             = "allUsers"
  data_source       = aws_appsync_datasource.ddb_users.name
  request_template  = <<EOF
{
	"version" : "2018-05-29",
	"operation" : "Scan"
}
EOF
  response_template = <<EOF
#if($ctx.error)
	$util.error($ctx.error.message, $ctx.error.type)
#end
#foreach($item in $ctx.result.items)
	#if($item.type == "admin")
		$util.qr($item.put("__typename", "AdminUser"))
	#else
		$util.qr($item.put("__typename", "NormalUser"))
	#end
#end
$utils.toJson($ctx.result.items)
EOF
}

resource "aws_appsync_function" "Query_search_1" {
  api_id            = aws_appsync_graphql_api.appsync.id
	name = "func1"
  data_source       = aws_appsync_datasource.ddb_files.name
  request_mapping_template  = <<EOF
{
	"version" : "2018-05-29",
	"operation" : "Scan",
	"filter" : {
		"expression" : "contains(#filename, :text)",
		"expressionValues" : {
			":text" : {"S": $util.toJson($ctx.args.text)}
		},
		"expressionNames": {
			"#filename": "filename"
		}
	}
}
EOF
  response_mapping_template = <<EOF
#if($ctx.error)
	$util.error($ctx.error.message, $ctx.error.type)
#end
#foreach($item in $ctx.result.items)
	$util.qr($item.put("__typename", "File"))
#end
$util.toJson($ctx.result.items)
EOF
}

resource "aws_appsync_function" "Query_search_2" {
  api_id            = aws_appsync_graphql_api.appsync.id
	name = "func2"
  data_source       = aws_appsync_datasource.ddb_documents.name
  request_mapping_template  = <<EOF
{
	"version" : "2018-05-29",
	"operation" : "Scan",
	"filter" : {
		"expression" : "contains(#contents, :text)",
		"expressionValues" : {
			":text" : {"S": $util.toJson($ctx.args.text)}
		},
		"expressionNames": {
			"#contents": "contents"
		}
	}
}
EOF
  response_mapping_template = <<EOF
#if($ctx.error)
	$util.error($ctx.error.message, $ctx.error.type)
#end
#foreach($item in $ctx.result.items)
	$util.qr($item.put("__typename", "Document"))
#end
$util.qr($ctx.result.items.addAll($ctx.prev.result))
$util.toJson($ctx.result.items)
EOF
}

resource "aws_appsync_resolver" "Query_search" {
  api_id      = aws_appsync_graphql_api.appsync.id
  type        = "Query"
  field       = "search"
  request_template  = "{}"
  response_template = "$util.toJson($ctx.result)"
  kind              = "PIPELINE"
  pipeline_config {
    functions = [
      aws_appsync_function.Query_search_1.function_id,
      aws_appsync_function.Query_search_2.function_id,
    ]
  }
}
