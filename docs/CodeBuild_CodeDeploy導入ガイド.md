# AWS CodeBuild & CodeDeploy 導入ガイド

このプロジェクトでは、LinuxでWindowsコンテナイメージをビルドできない制約を克服するため、AWS CodeBuildとCodeDeployを使用したCI/CDパイプラインを構築します。

## 構成概要

```
GitHub Repository
    ↓ (Webhook)
AWS CodePipeline
    ↓
AWS CodeBuild (Windows Environment)
    ↓ (Build & Push)
Amazon ECR
    ↓ (Deploy)
Amazon ECS (Windows Cluster)
```

## 1. AWS CodeBuild プロジェクト設定

### 基本設定
```json
{
  "name": "windows-countdown-build",
  "description": "Windows countdown executable build and Docker image creation",
  "serviceRole": "arn:aws:iam::ACCOUNT_ID:role/service-role/codebuild-windows-countdown-service-role",
  "artifacts": {
    "type": "CODEPIPELINE"
  },
  "environment": {
    "type": "WINDOWS_SERVER_2022_CONTAINER",
    "image": "mcr.microsoft.com/windows/servercore:ltsc2022",
    "computeType": "BUILD_GENERAL1_LARGE",
    "privilegedMode": true
  },
  "source": {
    "type": "CODEPIPELINE",
    "buildspec": "buildspec.yml"
  }
}
```

### 環境変数
```json
{
  "environmentVariables": [
    {
      "name": "AWS_DEFAULT_REGION",
      "value": "ap-northeast-1"
    },
    {
      "name": "REPOSITORY_URI",
      "value": "ACCOUNT_ID.dkr.ecr.ap-northeast-1.amazonaws.com/countdown-test"
    }
  ]
}
```

## 2. IAMロール設定

### CodeBuild Service Role
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:GetAuthorizationToken",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:PutObject"
      ],
      "Resource": "arn:aws:s3:::codepipeline-artifacts-bucket/*"
    }
  ]
}
```

## 3. CodePipeline設定

### パイプライン構成
```json
{
  "pipeline": {
    "name": "windows-countdown-pipeline",
    "roleArn": "arn:aws:iam::ACCOUNT_ID:role/service-role/AWS-CodePipeline-Service-Role",
    "artifactStore": {
      "type": "S3",
      "location": "codepipeline-artifacts-ap-northeast-1-ACCOUNT_ID"
    },
    "stages": [
      {
        "name": "Source",
        "actions": [
          {
            "name": "Source",
            "actionTypeId": {
              "category": "Source",
              "owner": "ThirdParty",
              "provider": "GitHub",
              "version": "1"
            },
            "configuration": {
              "Owner": "YOUR_GITHUB_USERNAME",
              "Repo": "test-win-batch-on-aws-re",
              "Branch": "main",
              "OAuthToken": "{{resolve:secretsmanager:github-token}}"
            },
            "outputArtifacts": [
              {
                "name": "SourceOutput"
              }
            ]
          }
        ]
      },
      {
        "name": "Build",
        "actions": [
          {
            "name": "Build",
            "actionTypeId": {
              "category": "Build",
              "owner": "AWS",
              "provider": "CodeBuild",
              "version": "1"
            },
            "configuration": {
              "ProjectName": "windows-countdown-build"
            },
            "inputArtifacts": [
              {
                "name": "SourceOutput"
              }
            ],
            "outputArtifacts": [
              {
                "name": "BuildOutput"
              }
            ]
          }
        ]
      },
      {
        "name": "Deploy",
        "actions": [
          {
            "name": "Deploy",
            "actionTypeId": {
              "category": "Deploy",
              "owner": "AWS",
              "provider": "ECS",
              "version": "1"
            },
            "configuration": {
              "ClusterName": "windows-batch-test-cluster",
              "ServiceName": "countdown-test-service",
              "FileName": "imagedefinitions.json"
            },
            "inputArtifacts": [
              {
                "name": "BuildOutput"
              }
            ]
          }
        ]
      }
    ]
  }
}
```

## 4. セットアップ手順

### 4.0 ECRイメージ名の変更（オプション）

デフォルトでは `countdown-test` というイメージ名を使用しますが、別の名称に変更したい場合は以下の手順で変更できます：

#### 4.0.1 変更が必要なファイル一覧
- `setup-codebuild.ps1` - 自動セットアップスクリプト
- `codebuild/project.json` - CodeBuildプロジェクト設定
- `ecs/task-definition.json` - ECSタスク定義
- `buildspec.yml` または `buildspec-windows.yml` - ビルド仕様（環境変数として設定される場合）

#### 4.0.2 変更手順例：`countdown-test` → `my-windows-app` に変更する場合

**1. ECRリポジトリ作成時**
```powershell
# デフォルト
aws ecr create-repository --repository-name countdown-test --region ap-northeast-1

# 変更後
aws ecr create-repository --repository-name my-windows-app --region ap-northeast-1
```

**2. setup-codebuild.ps1 の変更**
```powershell
# 実行時にRepositoryNameパラメータを指定
```powershell
# 変更後
.\setup-codebuild.ps1 -AccountId "YOUR_AWS_ACCOUNT_ID" -RepositoryName "my-windows-app"
```
```

**3. 手動設定の場合の変更箇所**

`codebuild/project.json`:
```json
{
  "name": "REPOSITORY_URI",
  "value": "ACCOUNT_ID.dkr.ecr.ap-northeast-1.amazonaws.com/my-windows-app",
  "type": "PLAINTEXT"
}
```

`ecs/task-definition.json`:
```json
{
  "name": "countdown-container",
  "image": "ACCOUNT_ID.dkr.ecr.ap-northeast-1.amazonaws.com/my-windows-app:latest"
}
```

**4. 環境変数での一括変更**
```powershell
# PowerShellでの一括置換例
$newImageName = "my-windows-app"
$oldImageName = "countdown-test"

# 設定ファイルの一括更新
Get-ChildItem -Path . -Include "*.json", "*.yml", "*.ps1" -Recurse | 
    ForEach-Object {
        (Get-Content $_.FullName) -replace $oldImageName, $newImageName | 
        Set-Content $_.FullName
    }
```

### 4.1 ECRリポジトリ作成
```powershell
aws ecr create-repository --repository-name countdown-test --region ap-northeast-1
```

### 4.2 CodeBuildプロジェクト作成
```powershell
# project.json ファイルを作成後
aws codebuild create-project --cli-input-json file://project.json
```

### 4.3 CodePipeline作成
```powershell
# pipeline.json ファイルを作成後
aws codepipeline create-pipeline --cli-input-json file://pipeline.json
```

### 4.4 GitHub Webhook設定
GitHubリポジトリにWebhookを設定して、pushイベントでパイプラインをトリガーします。

## 5. 手動デプロイ手順（CodePipelineなしの場合）

### 5.1 ローカルでの実行ファイルビルド
```powershell
cd execution
# Windows環境でのビルド
.\build.bat
# または Docker を使用
.\docker-build.bat
```

### 5.2 CodeBuildでのイメージビルド
```powershell
# CodeBuild プロジェクトを手動実行
aws codebuild start-build --project-name windows-countdown-build
```

### 5.3 ECSサービス更新
```powershell
# タスク定義を更新
aws ecs register-task-definition --cli-input-json file://task-definition.json

# サービスを更新
aws ecs update-service --cluster windows-batch-test-cluster --service countdown-test-service --task-definition countdown-test-task:LATEST
```

## 6. モニタリングとトラブルシューティング

### 6.1 ビルドログの確認
```powershell
# CodeBuild ログを確認
aws logs describe-log-groups --log-group-name-prefix "/aws/codebuild/windows-countdown-build"
```

### 6.2 ECSタスクの状態確認
```powershell
# タスクの状態を確認
aws ecs describe-tasks --cluster windows-batch-test-cluster --tasks TASK_ARN
```

### 6.3 よくある問題と解決策

#### 問題1: Docker認証エラー
```
Error: Cannot perform an interactive login from a non TTY device
```
**解決策**: buildspec.ymlでECRログインコマンドを修正
```yaml
- aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin $REPOSITORY_URI_BASE
```

#### 問題2: Windows実行ファイルが見つからない
```
Error: countdown.exe not found
```
**解決策**: ソースコードにコンパイル済みの実行ファイルを含めるか、buildspec.ymlでコンパイル工程を追加

#### 問題3: CodeBuild環境でのDockerエラー
```
Error: docker: command not found
```
**解決策**: CodeBuild環境設定で `privilegedMode: true` を有効化

## 7. コスト最適化

### 7.1 CodeBuild使用量最適化
- **ビルド頻度**: プルリクエスト時のみ実行
- **コンピュートタイプ**: 必要最小限のサイズを使用
- **キャッシュ**: Dockerレイヤーキャッシュを有効化

### 7.2 料金目安
- **CodeBuild**: $0.005/分 (BUILD_GENERAL1_LARGE)
- **CodePipeline**: $1/月 (アクティブパイプライン)
- **ECR**: $0.10/GB/月 (ストレージ)

## 8. 次のステップ

1. **自動テスト追加**: ビルド成功後の自動テスト実行
2. **マルチブランチ対応**: 開発・本番環境の分離
3. **通知設定**: SNS経由でのビルド結果通知
4. **セキュリティ強化**: 脆弱性スキャンの追加

## 関連ファイル

- `buildspec.yml` - CodeBuildビルド仕様
- `task-definition.json` - ECSタスク定義
- `project.json` - CodeBuildプロジェクト設定
- `pipeline.json` - CodePipelineパイプライン設定
