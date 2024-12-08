# API Gatewayのメインリソースを作成
resource "aws_api_gateway_rest_api" "example" {
  name        = "example-api"  # APIの名前
  description = "Example API Gateway"  # APIの説明
}

# API Gateway内のリソース（エンドポイント）を定義
resource "aws_api_gateway_resource" "example" {
  rest_api_id = aws_api_gateway_rest_api.example.id  # 上で作成したAPIのID
  parent_id   = aws_api_gateway_rest_api.example.root_resource_id  # ルートリソースのID
  path_part   = "example"  # このリソースのパス（/example となります）
}

# API Gatewayのメソッドを定義
# 特定のリソースに対してどのHTTPメソッドを許可するかを指定する
resource "aws_api_gateway_method" "example" {
  rest_api_id   = aws_api_gateway_rest_api.example.id  # APIのID
  resource_id   = aws_api_gateway_resource.example.id  # リソースのID
  http_method   = "GET"  # HTTPメソッド（GET, POST, PUT, DELETE等）
  authorization = "NONE"  # 認証方法（ここではNONEで認証なし）
}

# Lambda関数を作成
# API Gatewayからのリクエストを処理する関数
resource "aws_lambda_function" "example" {
  filename      = "lambda_function_payload.zip"  # Lambda関数のコードを含むZIPファイル
  function_name = "example_lambda"  # Lambda関数の名前
  role          = aws_iam_role.lambda_exec.arn  # Lambda関数が使用するIAMロールのARN
  handler       = "index.handler"  # Lambda関数のエントリーポイント
  runtime       = "nodejs18.x"  # Lambda関数の実行環境
}

# Lambda関数用のIAMロールを作成
# Lambda関数に必要な権限を付与する
resource "aws_iam_role" "lambda_exec" {
  name = "lambda_exec_role"  # IAMロールの名前

  # ロールの信頼ポリシーを定義
  # Lambda serviceがこのロールを引き受けることができる
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# API GatewayがLambda関数を呼び出すための許可を設定
resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"  # 許可の識別子
  action        = "lambda:InvokeFunction"  # 許可するアクション
  function_name = aws_lambda_function.example.function_name  # 許可を与えるLambda関数
  principal     = "apigateway.amazonaws.com"  # 許可を与えるサービス（API Gateway）
  source_arn    = "${aws_api_gateway_rest_api.example.execution_arn}/*/*"  # 許可の範囲（全てのメソッドと全てのリソース）
}

# API GatewayとLambda関数を統合
# API GatewayがLambda関数を呼び出すことができる
resource "aws_api_gateway_integration" "example" {
  rest_api_id             = aws_api_gateway_rest_api.example.id  # APIのID
  resource_id             = aws_api_gateway_resource.example.id  # リソースのID
  http_method             = aws_api_gateway_method.example.http_method  # HTTPメソッド
  integration_http_method = "POST"  # Lambda関数を呼び出す際のHTTPメソッド
  type                    = "AWS_PROXY"  # 統合タイプ（AWS_PROXYはLambda関数用）
  uri                     = aws_lambda_function.example.invoke_arn  # Lambda関数の呼び出しURI
}

# API Gatewayのデプロイメントを作成
# API Gatewayの設定変更が反映される
resource "aws_api_gateway_deployment" "example" {
  depends_on  = [aws_api_gateway_integration.example]  # 統合設定が完了してから実行
  rest_api_id = aws_api_gateway_rest_api.example.id  # APIのID
}

# CloudWatch Logsのロググループを作成
# API Gatewayのログを保存
resource "aws_cloudwatch_log_group" "example" {
  name = "/aws/api-gateway/example"  # ロググループの名前
}

# API Gatewayのステージを作成
# APIのデプロイ環境（例：開発、テスト、本番）を定義します。
resource "aws_api_gateway_stage" "example" {
  deployment_id = aws_api_gateway_deployment.example.id  # デプロイメントのID
  rest_api_id   = aws_api_gateway_rest_api.example.id  # APIのID
  stage_name    = "prod"  # ステージの名前

  # アクセスログの設定
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.example.arn  # ログの保存先
    format = jsonencode({  # ログのフォーマット
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      resourcePath   = "$context.resourcePath"
      status         = "$context.status"
      responseLength = "$context.responseLength"
    })
  }
}

# APIを実行するためのURLを表示
output "api_gateway_invoke_url" {
  value = "${aws_api_gateway_stage.example.invoke_url}/example"
}