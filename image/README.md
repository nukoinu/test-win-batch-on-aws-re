# Windows Test Image Builder

Windows Server 2022ベースのDockerイメージビルド・デプロイメント用スクリプト集

## ファイル構成

- `Dockerfile` - Windows Server 2022ベースのテストイメージ定義
- `build-image.bat` - Windowsでのイメージビルドスクリプト
- `build-image.sh` - Linux/macOSでのイメージビルドスクリプト
- `push-to-ecr.bat` - WindowsでのECRプッシュスクリプト
- `push-to-ecr.sh` - Linux/macOSでのECRプッシュスクリプト

## 使用方法

### 1. イメージのビルド

#### Windows環境
```cmd
build-image.bat
```

#### Linux/macOS環境
```bash
chmod +x build-image.sh
./build-image.sh
```

### 2. ECRへのプッシュ

#### Windows環境
```cmd
# AWSアカウントIDを指定
push-to-ecr.bat YOUR_AWS_ACCOUNT_ID

# リージョンとリポジトリ名も指定
push-to-ecr.bat YOUR_AWS_ACCOUNT_ID ap-northeast-1 my-countdown-test
```

#### Linux/macOS環境
```bash
chmod +x push-to-ecr.sh

# AWSアカウントIDを指定
./push-to-ecr.sh YOUR_AWS_ACCOUNT_ID

# リージョンとリポジトリ名も指定
./push-to-ecr.sh YOUR_AWS_ACCOUNT_ID ap-northeast-1 my-countdown-test
```

## 前提条件

### 必要なソフトウェア
- Docker Desktop (Windows containers対応)
- AWS CLI v2
- PowerShell (Windows)

### AWS設定
- AWS認証情報の設定 (`aws configure` または環境変数)
- ECRへの適切な権限

### ディレクトリ構造
```
test-win-batch-on-aws-re/
├── execution/
│   ├── countdown.exe    # ビルド済み実行ファイル
│   └── countdown.cpp    # ソースコード
└── image/               # このディレクトリ
    ├── Dockerfile
    ├── build-image.bat
    ├── build-image.sh
    ├── push-to-ecr.bat
    └── push-to-ecr.sh
```

## イメージの詳細

- **ベースイメージ**: `mcr.microsoft.com/windows/server:ltsc2022`
- **作業ディレクトリ**: `C:\app`
- **実行ファイル**: `C:\app\countdown.exe`
- **実行スクリプト**: `C:\app\run.ps1`

## トラブルシューティング

### Windows Containers未対応
Docker DesktopでWindows Containersモードに切り替えてください：
```
"C:\Program Files\Docker\Docker\DockerCli.exe" -SwitchWindowsEngine
```

### countdown.exe不存在
executionディレクトリでビルドを実行してください：
```cmd
cd ..\execution
build.bat
```

### ECR認証エラー
AWS CLIの設定を確認してください：
```cmd
aws configure list
aws sts get-caller-identity
```
