# AWS CodeBuild & CodeDeploy クイックスタートスクリプト
# 【廃止】このスクリプトは廃止されました
# 手動セットアップ手順を使用してください: docs/手動セットアップ手順.md

Write-Host "このスクリプトは廃止されました。" -ForegroundColor Red
Write-Host "手動セットアップ手順を使用してください:" -ForegroundColor Yellow
Write-Host "  docs/手動セットアップ手順.md" -ForegroundColor Cyan
Write-Host ""
Write-Host "リソースの確認・削除には以下のツールを使用してください:" -ForegroundColor Yellow
Write-Host "  .\cleanup-resources.ps1          # リソース確認" -ForegroundColor Cyan
Write-Host "  .\cleanup-resources.ps1 -Delete  # リソース削除" -ForegroundColor Cyan
exit 1

# 色付きメッセージ出力関数
function Write-ColorMessage {
    param([string]$Message, [string]$Color = "Green")
    Write-Host $Message -ForegroundColor $Color
}

function Write-ErrorMessage {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Red
}

function Write-InfoMessage {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Cyan
}

Write-ColorMessage "=== AWS CodeBuild & CodeDeploy セットアップ開始 ==="

# AWS CLI の確認
Write-InfoMessage "AWS CLI バージョンを確認中..."
try {
    $awsVersion = aws --version
    Write-ColorMessage "AWS CLI: $awsVersion"
} catch {
    Write-ErrorMessage "AWS CLI がインストールされていません。先にAWS CLIをインストールしてください。"
    exit 1
}

# AWS認証情報の確認
Write-InfoMessage "AWS認証情報を確認中..."
try {
    $identityJson = aws sts get-caller-identity --output json
    $identity = $identityJson | ConvertFrom-Json
    Write-ColorMessage "認証済み AWS Account: $($identity.Account)"
    Write-ColorMessage "認証済み User/Role: $($identity.Arn)"
} catch {
    Write-ErrorMessage "AWS認証が設定されていません。'aws configure' を実行してください。"
    exit 1
}

# 1. ECRリポジトリ作成
Write-InfoMessage "ECRリポジトリを作成中..."
try {
    aws ecr create-repository --repository-name $RepositoryName --region $Region --output table
    Write-ColorMessage "ECRリポジトリ '$RepositoryName' が作成されました"
} catch {
    Write-InfoMessage "ECRリポジトリは既に存在している可能性があります（エラーを無視）"
}

# 2. CloudWatch Logs グループ作成
Write-InfoMessage "CloudWatch Logsグループを作成中..."
try {
    aws logs create-log-group --log-group-name "/ecs/countdown-test" --region $Region
    aws logs create-log-group --log-group-name "/aws/codebuild/windows-countdown-build" --region $Region
    Write-ColorMessage "CloudWatch Logsグループが作成されました"
} catch {
    Write-InfoMessage "CloudWatch Logsグループは既に存在している可能性があります（エラーを無視）"
}

# 3. IAMロール作成
Write-InfoMessage "IAMロールを作成中..."

# CodeBuild サービスロール用信頼ポリシー
$codeBuildTrustPolicy = @"
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
"@

# CodeBuild サービスロール作成
try {
    $codeBuildTrustPolicy | Out-File -FilePath "codebuild-trust-policy.json" -Encoding UTF8
    aws iam create-role --role-name "codebuild-windows-countdown-service-role" --assume-role-policy-document file://codebuild-trust-policy.json --region $Region
    Write-ColorMessage "CodeBuild サービスロールが作成されました"
    
    # ポリシーのアタッチ（設定ファイルを更新）
    $policyContent = Get-Content "codebuild\codebuild-service-role-policy.json" -Raw -Encoding UTF8
    $policyContent = $policyContent -replace "ACCOUNT_ID", $AccountId
    $policyContent | Out-File -FilePath "codebuild-service-role-policy-updated.json" -Encoding UTF8
    
    aws iam put-role-policy --role-name "codebuild-windows-countdown-service-role" --policy-name "CodeBuildServiceRolePolicy" --policy-document file://codebuild-service-role-policy-updated.json
    Write-ColorMessage "CodeBuild サービスロールにポリシーがアタッチされました"
} catch {
    Write-InfoMessage "IAMロールは既に存在している可能性があります（エラーを無視）"
}

# ECS Task Execution Role (既存の場合はスキップ)
try {
    aws iam get-role --role-name ecsTaskExecutionRole --region $Region > $null
    Write-InfoMessage "ecsTaskExecutionRole は既に存在します"
} catch {
    Write-InfoMessage "ecsTaskExecutionRole を作成中..."
    $ecsTaskTrustPolicy = @"
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
"@
    
    $ecsTaskTrustPolicy | Out-File -FilePath "ecs-task-trust-policy.json" -Encoding UTF8
    aws iam create-role --role-name "ecsTaskExecutionRole" --assume-role-policy-document file://ecs-task-trust-policy.json --region $Region
    aws iam attach-role-policy --role-name "ecsTaskExecutionRole" --policy-arn "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy" --region $Region
    Write-ColorMessage "ecsTaskExecutionRole が作成されました"
}

# 4. 設定ファイルの更新
Write-InfoMessage "設定ファイルを更新中..."

# CodeBuild プロジェクト設定の更新
$projectConfig = Get-Content "codebuild\project.json" -Raw -Encoding UTF8
$projectConfig = $projectConfig -replace "ACCOUNT_ID", $AccountId
$projectConfig = $projectConfig -replace "countdown-test", $RepositoryName
$projectConfig | Out-File -FilePath "codebuild\project-updated.json" -Encoding UTF8

# ECS タスク定義の更新
$taskDefinition = Get-Content "ecs\task-definition.json" -Raw -Encoding UTF8
$taskDefinition = $taskDefinition -replace "ACCOUNT_ID", $AccountId
$taskDefinition = $taskDefinition -replace "countdown-test", $RepositoryName
$taskDefinition | Out-File -FilePath "ecs\task-definition-updated.json" -Encoding UTF8

# buildspec.yml の更新（リポジトリURIの設定）
$buildspec = Get-Content "buildspec.yml" -Raw -Encoding UTF8
$repositoryUri = "$AccountId.dkr.ecr.$Region.amazonaws.com/$RepositoryName"
# buildspec.yml には環境変数として設定されるので、ここでは変更不要

Write-ColorMessage "設定ファイルが更新されました"

# 5. CodeBuildプロジェクト作成
Write-InfoMessage "CodeBuildプロジェクトを作成中..."
try {
    aws codebuild create-project --cli-input-json file://codebuild/project-updated.json --region $Region
    Write-ColorMessage "CodeBuildプロジェクト 'windows-countdown-build' が作成されました"
} catch {
    Write-InfoMessage "CodeBuildプロジェクトは既に存在している可能性があります（エラーを無視）"
}

# 6. ECSクラスタの確認・作成
Write-InfoMessage "ECSクラスタを確認中..."
try {
    aws ecs describe-clusters --clusters "windows-batch-test-cluster" --region $Region > $null
    Write-InfoMessage "ECSクラスタ 'windows-batch-test-cluster' は既に存在します"
} catch {
    Write-InfoMessage "ECSクラスタを作成中..."
    aws ecs create-cluster --cluster-name "windows-batch-test-cluster" --region $Region
    Write-ColorMessage "ECSクラスタ 'windows-batch-test-cluster' が作成されました"
}

# 7. 一時ファイルの削除
Write-InfoMessage "一時ファイルを削除中..."
Remove-Item -Path "codebuild-trust-policy.json" -ErrorAction SilentlyContinue
Remove-Item -Path "ecs-task-trust-policy.json" -ErrorAction SilentlyContinue
Remove-Item -Path "codebuild-service-role-policy-updated.json" -ErrorAction SilentlyContinue

Write-ColorMessage "=== セットアップ完了 ==="
Write-InfoMessage ""
Write-InfoMessage "次のステップ:"
Write-InfoMessage "1. プロジェクトアーカイブをS3にアップロード、またはローカルでCodeBuildを実行"
Write-InfoMessage "2. CodeBuildプロジェクトを手動実行:"
Write-InfoMessage "   aws codebuild start-build --project-name windows-countdown-build --region $Region"
Write-InfoMessage ""
Write-InfoMessage "3. ECSタスク定義を登録:"
Write-InfoMessage "   aws ecs register-task-definition --cli-input-json file://ecs/task-definition-updated.json --region $Region"
Write-InfoMessage ""
Write-InfoMessage "4. ECRリポジトリURI: $repositoryUri"
Write-InfoMessage ""
Write-ColorMessage "セットアップが正常に完了しました！"
