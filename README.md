# test-win-batch-on-aws-re

AWS Batch環境におけるWindows実行ファイルの多重起動検証プロジェクト

## 概要

このプロジェクトは、AWS BatchとECS環境でWindows実行ファイルを複数インスタンスで同時実行した際の動作検証を目的としています。Windows Server 2022ベースのDockerコンテナ上でC++製のカウントダウンプログラムを実行し、マルチインスタンス実行時の安定性、リソース競合、ログ出力の整合性を検証します。

## プロジェクト構成

```
test-win-batch-on-aws-re/
├── README.md                    # このファイル
├── docs/                        # 仕様書類
│   ├── ECS仕様.md               # ECSクラスタ・タスク構成仕様
│   ├── テストイメージ仕様.md      # Dockerイメージの詳細仕様
│   └── テスト実行ファイル仕様.md   # カウントダウンプログラムの仕様
├── ecs/                         # ECS関連設定ファイル
├── execution/                   # テスト実行ファイル関連
│   ├── countdown.cpp            # C++ソースコード
│   ├── build.bat               # Windowsローカルビルドスクリプト
│   ├── build.sh                # クロスプラットフォームビルドスクリプト
│   ├── docker-build.bat        # Windows用Dockerビルドスクリプト
│   ├── Dockerfile              # テスト用フル機能イメージ
│   ├── Dockerfile.build        # ビルド専用軽量イメージ
│   └── README.md               # ビルド手順とファイル詳細
└── image/                      # Dockerイメージ作成・デプロイ
    ├── Dockerfile              # Windows Server 2022ベースイメージ
    ├── build-image.bat         # Windowsイメージビルドスクリプト
    ├── build-image.sh          # Linux/macOSイメージビルドスクリプト
    ├── push-to-ecr.bat         # WindowsでのECRプッシュスクリプト
    ├── push-to-ecr.sh          # Linux/macOSでのECRプッシュスクリプト
    └── README.md               # イメージビルド・デプロイ手順
```

## クイックスタート

### 手動セットアップ（推奨）

自動セットアップスクリプトは廃止されました。詳細な手動手順については以下を参照してください：

📋 **[手動セットアップ手順](docs/手動セットアップ手順.md)** - AWS CodeBuild・ECS環境の段階的構築手順

### リソース管理ツール

作成したAWSリソースの確認・削除には専用ツールを使用できます：

```powershell
# リソース確認
.\cleanup-resources.ps1

# リソース削除（確認あり）
.\cleanup-resources.ps1 -Delete

# リソース削除（確認なし）
.\cleanup-resources.ps1 -Delete -Force
```

### 従来の手動ビルド方法（ローカルWindows環境）

Windows環境で直接ビルドする場合：

#### 1. 前提条件

- **Docker Desktop** (Windows containers対応)
- **MinGW-w64** または **w64devkit** (Windowsローカルビルド用)

#### 2. テスト実行ファイルのビルド

```powershell
# executionディレクトリに移動
cd execution

# Windowsローカルビルド（w64devkitまたはMinGW-w64環境）
.\build.bat

# またはDockerを使用したクロスプラットフォームビルド
.\docker-build.bat
```

#### 3. Dockerイメージの作成

```powershell
# imageディレクトリに移動
cd ..\image

# Dockerイメージをビルド
.\build-image.bat
```

#### 4. ECRへのデプロイ（オプション）

```powershell
# AWSアカウントIDを指定してECRにプッシュ（ap-northeast-1リージョン）
.\push-to-ecr.bat YOUR_AWS_ACCOUNT_ID

# リージョンとリポジトリ名も明示的に指定
.\push-to-ecr.bat YOUR_AWS_ACCOUNT_ID ap-northeast-1 my-countdown-test
```

## 検証項目

このプロジェクトでは以下の検証を実施します：

### 1. 単一インスタンス検証
- Windows実行ファイルの正常な起動・終了
- 適切なログ出力の確認
- リソース使用量の監視

### 2. 多重起動検証
- 複数インスタンスの同時実行
- インスタンス間のリソース競合チェック
- 各インスタンスの独立性確認

### 3. 長時間実行検証
- 数時間の連続実行テスト
- メモリリークの検出
- システム安定性の確認

### 4. エラーハンドリング検証
- 無効な引数に対する適切なエラー処理
- 異常終了時の動作確認

## 使用技術

- **プログラミング言語**: C++
- **コンテナ技術**: Docker (Windows containers)
- **ベースイメージ**: Windows Server 2022 LTSC
- **クラウドサービス**: AWS Batch, AWS ECS, Amazon ECR
- **ビルドツール**: MinGW-w64, w64devkit

## テスト実行ファイルの動作

`countdown.exe` は以下の動作を行います：

- **引数**: 秒数（整数）を受け取る
- **1〜99秒**: 1秒間隔でカウントダウン
- **100秒以上**: 指定時間の1/10間隔でカウントダウン
- **出力**: 標準出力にカウントダウン値を表示

```cmd
# 使用例
countdown.exe 30    # 30秒カウントダウン（1秒間隔）
countdown.exe 300   # 300秒カウントダウン（30秒間隔）
```

## 開発環境セットアップ

### Windows環境推奨：w64devkit

1. [w64devkit Releases](https://github.com/skeeto/w64devkit/releases)から最新版をダウンロード
2. 任意のフォルダに解凍（例：`C:\tools\w64devkit`）
3. `w64devkit.exe`を実行してターミナルを開く
4. プロジェクトフォルダに移動してビルド実行

### Docker環境での開発

Docker Desktopがインストールされていれば、どの環境でもWindows EXEをビルド可能です。

## ドキュメント

詳細な仕様と手順については以下のドキュメントを参照してください：

### AWS CodeBuild・CodeDeploy関連
- **[CodeBuild実行手順](docs/CodeBuild実行手順.md)** - AWS CodeBuildを使用した自動ビルド・デプロイの詳細手順
- **[CodeBuild_CodeDeploy導入ガイド](docs/CodeBuild_CodeDeploy導入ガイド.md)** - LinuxでのWindowsイメージビルド問題の解決策

### 仕様書・従来手順
- [ECS仕様](docs/ECS仕様.md) - Amazon ECSクラスタ・タスク構成仕様
- [テストイメージ仕様](docs/テストイメージ仕様.md) - Dockerイメージの詳細設計
- [テスト実行ファイル仕様](docs/テスト実行ファイル仕様.md) - カウントダウンプログラムの機能仕様
- [execution/README.md](execution/README.md) - ローカルビルド手順の詳細
- [image/README.md](image/README.md) - 手動イメージ作成・デプロイ手順

## ライセンス

このプロジェクトは検証目的のサンプルコードです。

## 貢献

プルリクエストやイシューの報告を歓迎します。

---

**注意**: このプロジェクトはWindows containers環境での動作を前提としています。Docker DesktopでWindows containersモードに切り替えてご利用ください。