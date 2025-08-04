# AWS CodeBuild を使用したWindows環境での自動ビルド・デプロイ手順

## 概要

LinuxでWindowsコンテナイメージをビルドできない問題を解決するため、AWS CodeBuildのWindows環境を使用してDockerイメージのビルドとデプロイを自動化します。

## 前提条件

- AWS CLI v2 がインストール・設定済み
- 適切なAWS IAM権限
- GitHubリポジトリへのアクセス

## クイックスタート

### 1. 自動セットアップスクリプトの実行

```powershell
# PowerShellでプロジェクトディレクトリに移動
cd path\to\test-win-batch-on-aws-re

# セットアップスクリプトを実行（アカウントIDは必須）
.\setup-codebuild.ps1 -AccountId "YOUR_AWS_ACCOUNT_ID"

# イメージ名を変更したい場合
.\setup-codebuild.ps1 -AccountId "YOUR_AWS_ACCOUNT_ID" -RepositoryName "my-windows-app"
```

このスクリプトは以下の作業を自動実行します：
- ECRリポジトリの作成
- CloudWatch Logsグループの作成  
- IAMロールとポリシーの作成
- CodeBuildプロジェクトの作成
- 設定ファイルの更新

### 2. 手動ビルドの実行

```powershell
# CodeBuildプロジェクトを手動実行
aws codebuild start-build --project-name windows-countdown-build --region ap-northeast-1
```

### 3. ECSタスク定義の登録

```powershell
# タスク定義を登録
aws ecs register-task-definition --cli-input-json file://ecs/task-definition-updated.json --region ap-northeast-1
```

## ECRイメージ名の変更

デフォルトのイメージ名 `countdown-test` を別の名称に変更したい場合：

### 自動セットアップ時の変更
```powershell
# RepositoryNameパラメータを指定
.\setup-codebuild.ps1 -AccountId "YOUR_AWS_ACCOUNT_ID" -RepositoryName "my-custom-app"
```

### ソースコードのアップロード
事前ビルドされた`countdown.exe`を含むプロジェクトをS3にアップロードする必要があります：

```powershell
# S3バケット作成
aws s3 mb s3://YOUR_AWS_ACCOUNT_ID-codebuild-source --region ap-northeast-1

# プロジェクトをzip化してアップロード
Compress-Archive -Path . -DestinationPath countdown-test-source.zip
aws s3 cp countdown-test-source.zip s3://YOUR_AWS_ACCOUNT_ID-codebuild-source/ --region ap-northeast-1
```

### 手動変更の場合
以下のファイルでイメージ名を変更：

1. **ECRリポジトリ作成**
```powershell
aws ecr create-repository --repository-name my-custom-app --region ap-northeast-1
```

2. **codebuild/project.json** - S3ソースロケーション
3. **ecs/task-definition.json** - containerDefinitions.image
4. **buildspec.yml** - 環境変数REPOSITORY_URI（CodeBuildプロジェクト設定から自動設定）

## 詳細な手動セットアップ手順

自動スクリプトを使用しない場合の手動セットアップ手順：

### 1. ECRリポジトリの作成

```powershell
aws ecr create-repository --repository-name countdown-test --region ap-northeast-1
```

### 2. IAMロールの作成

#### CodeBuild用サービスロール
```powershell
# 信頼ポリシーファイルの作成
@"
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
"@ | Out-File -FilePath trust-policy.json -Encoding UTF8

# ロールの作成
aws iam create-role --role-name codebuild-windows-countdown-service-role --assume-role-policy-document file://trust-policy.json

# ポリシーのアタッチ
aws iam put-role-policy --role-name codebuild-windows-countdown-service-role --policy-name CodeBuildServiceRolePolicy --policy-document file://codebuild/codebuild-service-role-policy.json
```

### 3. CodeBuildプロジェクトの作成

設定ファイルを編集してアカウントIDを更新：

```powershell
# project.json のアカウントIDを置換
(Get-Content codebuild\project.json) -replace 'ACCOUNT_ID', 'YOUR_AWS_ACCOUNT_ID' | Set-Content codebuild\project-updated.json

# S3バケット作成とソースアップロード
aws s3 mb s3://YOUR_AWS_ACCOUNT_ID-codebuild-source --region ap-northeast-1
Compress-Archive -Path . -DestinationPath countdown-test-source.zip
aws s3 cp countdown-test-source.zip s3://YOUR_AWS_ACCOUNT_ID-codebuild-source/ --region ap-northeast-1

# プロジェクトの作成
aws codebuild create-project --cli-input-json file://codebuild/project-updated.json
```

## ビルドプロセスの詳細

### buildspec.yml の動作

1. **pre_build フェーズ**
   - ECRへのログイン
   - イメージタグの設定

2. **build フェーズ**  
   - 事前ビルド済みの`countdown.exe`を使用
   - Dockerイメージのビルド

3. **post_build フェーズ**
   - ECRへのイメージプッシュ
   - ECS用のイメージ定義ファイル作成

### Windows固有の考慮事項

- **環境**: Windows Server 2022 Container
- **Docker**: Windows containers モード
- **シェル**: cmd.exe（PowerShellではなく）
- **パス区切り**: バックスラッシュ（\\）

## トラブルシューティング

### よくある問題と解決策

#### 1. ECRログインエラー
```
Error: Cannot perform an interactive login
```
**解決策**: buildspec.ymlでパスワードをパイプで渡す方式に修正済み

#### 2. 実行ファイルが見つからない
```
Error: countdown.exe not found
```
**解決策**: 
- 事前ビルド済みの`countdown.exe`がexecutionディレクトリに存在することを確認
- S3にアップロードするzipファイルに`countdown.exe`が含まれていることを確認

#### 3. CodeBuild権限エラー
```
AccessDenied: User is not authorized
```
**解決策**: IAMロールに適切な権限が付与されているか確認

### ログの確認方法

```powershell
# CodeBuildのログを確認
aws logs describe-log-streams --log-group-name "/aws/codebuild/windows-countdown-build" --region ap-northeast-1

# 最新のログストリームを表示
aws logs get-log-events --log-group-name "/aws/codebuild/windows-countdown-build" --log-stream-name "STREAM_NAME" --region ap-northeast-1
```

## S3ソースの管理

### プロジェクトの更新

```powershell
# プロジェクトを更新してS3に再アップロード
Compress-Archive -Path . -DestinationPath countdown-test-source.zip -Force
aws s3 cp countdown-test-source.zip s3://YOUR_AWS_ACCOUNT_ID-codebuild-source/ --region ap-northeast-1
```

## GitHub連携の設定

### Webhook の設定

1. GitHubリポジトリの Settings > Webhooks
2. Add webhook をクリック
3. Payload URL: CodeBuildのWebhook URL
4. Content type: application/json
5. Events: Push events

### 自動ビルドの設定

S3ソースを使用する場合、プッシュイベントによる自動ビルドは利用できません。手動でCodeBuildを実行するか、別のトリガー方式（Lambda、EventBridge等）を使用してください。

```powershell
# 手動ビルド実行
aws codebuild start-build --project-name windows-countdown-build --region ap-northeast-1
```

## ECSへのデプロイ

### サービスの作成

```powershell
# ECSクラスタの作成（未作成の場合）
aws ecs create-cluster --cluster-name windows-batch-test-cluster

# サービスの作成
aws ecs create-service --cluster windows-batch-test-cluster --service-name countdown-test-service --task-definition countdown-test-task:1 --desired-count 1
```

### サービスの更新

```powershell
# 新しいタスク定義でサービスを更新
aws ecs update-service --cluster windows-batch-test-cluster --service countdown-test-service --task-definition countdown-test-task:LATEST
```

## コスト管理

### 推奨設定
- **CodeBuildインスタンス**: BUILD_GENERAL1_LARGE（必要最小限）
- **ビルド頻度**: プルリクエスト時のみ
- **イメージ保持**: ECRで古いイメージの自動削除設定

### 料金目安
- **CodeBuild**: $0.005/分（BUILD_GENERAL1_LARGE）
- **ECR**: $0.10/GB/月（ストレージ）
- **CloudWatch Logs**: $0.50/GB（ingestion）

## 次のステップ

1. **CodePipeline との統合**: 完全なCI/CDパイプラインの構築
2. **自動テストの追加**: ビルド後の自動テスト実行
3. **マルチ環境対応**: 開発・ステージング・本番環境の分離
4. **監視とアラート**: CloudWatchでの詳細監視設定

## 関連ファイル

- `buildspec.yml` - Linux/汎用環境用
- `buildspec-windows.yml` - Windows専用環境用  
- `setup-codebuild.ps1` - 自動セットアップスクリプト
- `codebuild/project.json` - CodeBuildプロジェクト設定
- `ecs/task-definition.json` - ECSタスク定義
