# カウントダウンテスト実行ファイル

AWS Batch/ECS マルチインスタンス実行動作検証用のWindows EXEファイル。

## ファイル概要

- `countdown.cpp` - C++ソースコード
- `build.bat` - Windows用ローカルビルドスクリプト
- `docker-build.bat` - Windows用Dockerビルドスクリプト
- `build.sh` - macOS/Linux用Dockerビルドスクリプト
- `Dockerfile` - テスト用フル機能Dockerイメージ（Wine付き）
- `Dockerfile.build` - ビルド専用軽量Dockerイメージ

## ビルド方法

### Windowsローカルビルド

**必要な環境:**
- MinGW-w64 または Visual Studio Build Tools
- g++コンパイラがPATHに設定されていること

**推奨セットアップ（w64devkit）:**
1. [w64devkit Releases](https://github.com/skeeto/w64devkit/releases) から最新版をダウンロード
2. 任意のフォルダに解凍（例：`C:\w64devkit`）
3. `w64devkit.exe` を実行してターミナルを開く
4. このフォルダに移動して以下を実行

```cmd
build.bat
```

### クロスプラットフォームDockerビルド

**必要な環境:**
- Docker Desktop

**Windows:**
```cmd
docker-build.bat
```

**macOS/Linux:**
```bash
chmod +x build.sh
./build.sh
```

### 手動Dockerビルド

```bash
# 軽量Dockerfileを使用してビルド
docker build -f Dockerfile.build -t countdown-builder .

# 実行ファイルを抽出
docker create --name temp-countdown countdown-builder
docker cp temp-countdown:/build/countdown.exe .
docker rm temp-countdown
```

## 使用方法

```cmd
# 10秒カウントダウン（1秒間隔）
countdown.exe 10

# 300秒カウントダウン（30秒間隔）
countdown.exe 300
```

## 動作仕様

- **1〜99秒**: 1秒間隔でカウントダウン
- **100秒以上**: 指定時間の1/10間隔でカウントダウン
- **エラーハンドリング**: 無効な入力に対して英語でエラーメッセージを表示

## 出力例

**30秒の場合:**
```
30
29
28
...
2
1
0
```

**200秒の場合（20秒間隔）:**
```
200
180
160
...
40
20
0
```

## AWS Batch/ECS検証用途

この実行ファイルは以下の検証に使用されます：
- マルチインスタンス同時実行テスト
- リソース競合状態の確認
- 長時間実行時の安定性テスト
- ログ出力の整合性確認
