# ECS仕様

## 概要
Windows実行ファイル多重起動検証用のAmazon ECSクラスタ構成仕様。Windows Server 2022ベースのDockerコンテナを複数インスタンスで同時実行し、マルチインスタンス環境での動作検証を実施する。

## クラスタ基本仕様

### クラスタ設定
- **クラスタ名**: `windows-batch-test-cluster`
- **起動タイプ**: EC2
- **リージョン**: ap-northeast-1 (東京)
- **プラットフォーム**: Windows

### インフラストラクチャ設定
- **容量プロバイダー**: EC2 Auto Scaling
- **インスタンスタイプ**: 
  - 推奨: `m5.large` または `m5.xlarge`
  - 最小: `t3.medium` (テスト用途)
- **AMI**: Windows Server 2022 ECS-Optimized AMI
- **Auto Scaling設定**:
  - 最小容量: 1
  - 最大容量: 5
  - 希望容量: 2

## EC2インスタンス仕様

### 基本設定
- **オペレーティングシステム**: Windows Server 2022
- **アーキテクチャ**: x86_64
- **EBS最適化**: 有効
- **詳細モニタリング**: 有効

### ストレージ設定
- **ルートボリューム**: 
  - タイプ: gp3
  - サイズ: 50GB
  - IOPS: 3000
  - スループット: 125 MB/s

### ネットワーク設定
- **VPC**: デフォルトVPCまたは専用VPC
- **サブネット**: パブリックサブネット
- **セキュリティグループ**: ECS専用セキュリティグループ
- **パブリックIP**: 自動割り当て有効

### IAMロール
```json
{
  "Role": "ecsInstanceRole",
  "ManagedPolicies": [
    "AmazonECSTaskExecutionRolePolicy",
    "AmazonEC2ContainerServiceforEC2Role"
  ]
}
```

## タスク定義仕様

### 基本設定
- **ファミリー名**: `countdown-test-task`
- **起動タイプ**: EC2
- **ネットワークモード**: default
- **オペレーティングシステム**: Windows_Server_2022_Core

### コンテナ定義
```json
{
  "name": "countdown-container",
  "image": "YOUR_ACCOUNT_ID.dkr.ecr.ap-northeast-1.amazonaws.com/countdown-test:latest",
  "memory": 512,
  "cpu": 256,
  "essential": true,
  "logConfiguration": {
    "logDriver": "awslogs",
    "options": {
      "awslogs-group": "/ecs/countdown-test",
      "awslogs-region": "ap-northeast-1",
      "awslogs-stream-prefix": "ecs"
    }
  },
  "command": ["countdown.exe", "300"],
  "workingDirectory": "C:\\app"
}
```

### リソース設定
- **タスクCPU**: 256 CPU単位 (0.25 vCPU)
- **タスクメモリ**: 512 MB
- **実行ロール**: `ecsTaskExecutionRole`

## サービス設定

### 基本設定
- **サービス名**: `countdown-test-service`
- **起動タイプ**: EC2
- **プラットフォームバージョン**: LATEST
- **クラスター**: `windows-batch-test-cluster`

### デプロイメント設定
- **希望するタスク数**: 1-5 (検証用途に応じて調整)
- **デプロイメント設定**:
  - タイプ: Rolling Update
  - 最小正常性パーセント: 50%
  - 最大パーセント: 200%

### ネットワーク設定
- **VPC**: クラスターと同じVPC
- **サブネット**: パブリックサブネット
- **セキュリティグループ**: 
  - インバウンド: なし（外部接続不要）
  - アウトバウンド: 全て許可

## ログ設定

### CloudWatch Logs
- **ロググループ名**: `/ecs/countdown-test`
- **保持期間**: 7日
- **リージョン**: ap-northeast-1

### ログの内容
- カウントダウンの進行状況
- 開始・終了時刻
- エラーメッセージ（発生時）

## モニタリング設定

### CloudWatch メトリクス
- **CPU使用率**: 5分間隔
- **メモリ使用率**: 5分間隔
- **タスク数**: リアルタイム
- **ネットワークトラフィック**: 5分間隔

### アラーム設定
```json
{
  "AlarmName": "ECS-HighCPU",
  "MetricName": "CPUUtilization",
  "Threshold": 80,
  "ComparisonOperator": "GreaterThanThreshold",
  "EvaluationPeriods": 2,
  "Period": 300
}
```

## セキュリティ仕様

### セキュリティグループ設定
```json
{
  "GroupName": "ecs-windows-test-sg",
  "Description": "Security group for Windows ECS test cluster",
  "VpcId": "vpc-xxxxxxxxx",
  "SecurityGroupRules": [
    {
      "IpPermissions": [],
      "IpPermissionsEgress": [
        {
          "IpProtocol": "-1",
          "CidrIp": "0.0.0.0/0"
        }
      ]
    }
  ]
}
```

### IAMロール・ポリシー
- **タスク実行ロール**: ECRアクセス、CloudWatch Logsアクセス
- **タスクロール**: 必要最小限の権限のみ

## 検証シナリオ

### 1. 単一タスク検証
- **設定**: タスク数 = 1
- **実行時間**: 300秒 (5分)
- **確認項目**: 
  - 正常起動・終了
  - ログ出力の完全性
  - リソース使用量

### 2. 並列タスク検証
- **設定**: タスク数 = 3-5
- **実行時間**: 600秒 (10分)
- **確認項目**:
  - 同時実行の安定性
  - リソース競合の有無
  - 各タスクの独立性

### 3. 長時間実行検証
- **設定**: タスク数 = 2
- **実行時間**: 3600秒 (1時間)
- **確認項目**:
  - 長時間実行の安定性
  - メモリリークの検出
  - システムリソースの推移

### 4. 負荷テスト
- **設定**: タスク数 = 最大5
- **実行時間**: 1800秒 (30分)
- **確認項目**:
  - インスタンスの自動スケーリング
  - 高負荷時の安定性
  - パフォーマンスの劣化

## トラブルシューティング

### よくある問題

#### 1. タスクが起動しない
- **原因**: ECRイメージのプル失敗
- **確認**: IAMロールの権限、ECRリポジトリの存在
- **対処**: タスク実行ロールにECRアクセス権限を付与

#### 2. コンテナが即座に終了
- **原因**: 実行ファイルのパスエラー
- **確認**: Dockerイメージ内のファイル配置
- **対処**: タスク定義のworkingDirectoryとcommandを確認

#### 3. ログが出力されない
- **原因**: CloudWatch Logsの設定不備
- **確認**: ロググループの存在、IAMロールの権限
- **対処**: awslogs設定とロググループを確認

### デバッグ手順
1. ECSコンソールでタスクのステータス確認
2. CloudWatch Logsでコンテナログを確認
3. EC2インスタンスのECSエージェントログを確認
4. イベントタブでタスクの起動履歴を確認

## コスト最適化

### 推奨設定
- **開発・テスト環境**: t3.mediumインスタンス
- **本格検証環境**: m5.largeインスタンス
- **スポットインスタンス**: コスト削減のため利用を検討
- **Auto Scaling**: 需要に応じた自動調整

### 料金目安（ap-northeast-1）
- **t3.medium**: 約$0.0464/時間
- **m5.large**: 約$0.096/時間
- **CloudWatch Logs**: $0.033/GB
- **データ転送**: 基本的に無料（同一リージョン内）

## 関連ドキュメント
- [テストイメージ仕様](./テストイメージ仕様.md)
- [テスト実行ファイル仕様](./テスト実行ファイル仕様.md)
- [AWS Batch仕様](./AWS_Batch仕様.md) ※今後作成予定
- [image/README.md](../image/README.md)
