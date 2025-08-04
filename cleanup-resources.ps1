# AWS CodeBuild & ECS リソース確認・削除ツール
# Windows PowerShell用

param(
    [Parameter(Mandatory=$false)]
    [string]$Region = "ap-northeast-1",
    
    [Parameter(Mandatory=$false)]
    [string]$RepositoryName = "countdown-test",
    
    [Parameter(Mandatory=$false)]
    [switch]$Delete = $false,
    
    [Parameter(Mandatory=$false)]
    [switch]$Force = $false
)

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

function Write-WarningMessage {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Yellow
}

Write-ColorMessage "=== AWS リソース確認・削除ツール ==="
Write-InfoMessage "Region: $Region"
Write-InfoMessage "Repository: $RepositoryName"

if ($Delete) {
    Write-WarningMessage "削除モードが有効です。リソースが削除されます。"
    if (-not $Force) {
        $confirmation = Read-Host "続行しますか? (y/N)"
        if ($confirmation -ne "y" -and $confirmation -ne "Y") {
            Write-InfoMessage "処理を中止しました。"
            exit 0
        }
    }
} else {
    Write-InfoMessage "確認モードです。リソースの状態を表示します。"
}

Write-InfoMessage ""

# 1. ECRリポジトリの確認・削除
Write-InfoMessage "=== ECRリポジトリ ==="
try {
    $ecrRepo = aws ecr describe-repositories --repository-names $RepositoryName --region $Region --output json 2>$null | ConvertFrom-Json
    if ($ecrRepo.repositories) {
        Write-ColorMessage "✓ ECRリポジトリ '$RepositoryName' が存在します"
        $repo = $ecrRepo.repositories[0]
        Write-Host "  URI: $($repo.repositoryUri)"
        Write-Host "  作成日: $($repo.createdAt)"
        
        if ($Delete) {
            Write-WarningMessage "ECRリポジトリを削除中..."
            aws ecr delete-repository --repository-name $RepositoryName --region $Region --force
            Write-ColorMessage "ECRリポジトリが削除されました"
        }
    } else {
        Write-InfoMessage "ECRリポジトリ '$RepositoryName' は存在しません"
    }
} catch {
    Write-InfoMessage "ECRリポジトリ '$RepositoryName' は存在しません"
}

# 2. CloudWatch Logsグループの確認・削除
Write-InfoMessage ""
Write-InfoMessage "=== CloudWatch Logs グループ ==="
$logGroups = @("/ecs/countdown-test", "/aws/codebuild/windows-countdown-build")

foreach ($logGroup in $logGroups) {
    try {
        $result = aws logs describe-log-groups --log-group-name-prefix $logGroup --region $Region --output json 2>$null | ConvertFrom-Json
        if ($result.logGroups -and $result.logGroups.Count -gt 0) {
            $group = $result.logGroups | Where-Object { $_.logGroupName -eq $logGroup }
            if ($group) {
                Write-ColorMessage "✓ CloudWatch Logsグループ '$logGroup' が存在します"
                Write-Host "  作成日: $($group.creationTime)"
                Write-Host "  保存期間: $($group.retentionInDays)"
                
                if ($Delete) {
                    Write-WarningMessage "CloudWatch Logsグループ '$logGroup' を削除中..."
                    aws logs delete-log-group --log-group-name $logGroup --region $Region
                    Write-ColorMessage "CloudWatch Logsグループが削除されました"
                }
            } else {
                Write-InfoMessage "CloudWatch Logsグループ '$logGroup' は存在しません"
            }
        } else {
            Write-InfoMessage "CloudWatch Logsグループ '$logGroup' は存在しません"
        }
    } catch {
        Write-InfoMessage "CloudWatch Logsグループ '$logGroup' は存在しません"
    }
}

# 3. IAMロールの確認・削除
Write-InfoMessage ""
Write-InfoMessage "=== IAMロール ==="
$roles = @("codebuild-windows-countdown-service-role", "ecsTaskExecutionRole")

foreach ($roleName in $roles) {
    try {
        $role = aws iam get-role --role-name $roleName --output json 2>$null | ConvertFrom-Json
        if ($role.Role) {
            Write-ColorMessage "✓ IAMロール '$roleName' が存在します"
            Write-Host "  ARN: $($role.Role.Arn)"
            Write-Host "  作成日: $($role.Role.CreateDate)"
            
            if ($Delete) {
                Write-WarningMessage "IAMロール '$roleName' を削除中..."
                
                # アタッチされたポリシーを削除
                try {
                    $policies = aws iam list-attached-role-policies --role-name $roleName --output json 2>$null | ConvertFrom-Json
                    foreach ($policy in $policies.AttachedPolicies) {
                        aws iam detach-role-policy --role-name $roleName --policy-arn $policy.PolicyArn
                        Write-InfoMessage "  ポリシー $($policy.PolicyName) をデタッチしました"
                    }
                } catch {}
                
                # インラインポリシーを削除
                try {
                    $inlinePolicies = aws iam list-role-policies --role-name $roleName --output json 2>$null | ConvertFrom-Json
                    foreach ($policyName in $inlinePolicies.PolicyNames) {
                        aws iam delete-role-policy --role-name $roleName --policy-name $policyName
                        Write-InfoMessage "  インラインポリシー $policyName を削除しました"
                    }
                } catch {}
                
                # ロールを削除
                aws iam delete-role --role-name $roleName
                Write-ColorMessage "IAMロールが削除されました"
            }
        } else {
            Write-InfoMessage "IAMロール '$roleName' は存在しません"
        }
    } catch {
        Write-InfoMessage "IAMロール '$roleName' は存在しません"
    }
}

# 4. CodeBuildプロジェクトの確認・削除
Write-InfoMessage ""
Write-InfoMessage "=== CodeBuildプロジェクト ==="
$projectName = "windows-countdown-build"
try {
    $project = aws codebuild batch-get-projects --names $projectName --region $Region --output json 2>$null | ConvertFrom-Json
    if ($project.projects -and $project.projects.Count -gt 0) {
        Write-ColorMessage "✓ CodeBuildプロジェクト '$projectName' が存在します"
        $proj = $project.projects[0]
        Write-Host "  ARN: $($proj.arn)"
        Write-Host "  作成日: $($proj.created)"
        Write-Host "  サービスロール: $($proj.serviceRole)"
        
        if ($Delete) {
            Write-WarningMessage "CodeBuildプロジェクト '$projectName' を削除中..."
            aws codebuild delete-project --name $projectName --region $Region
            Write-ColorMessage "CodeBuildプロジェクトが削除されました"
        }
    } else {
        Write-InfoMessage "CodeBuildプロジェクト '$projectName' は存在しません"
    }
} catch {
    Write-InfoMessage "CodeBuildプロジェクト '$projectName' は存在しません"
}

# 5. ECSクラスタの確認・削除
Write-InfoMessage ""
Write-InfoMessage "=== ECSクラスタ ==="
$clusterName = "windows-batch-test-cluster"
try {
    $cluster = aws ecs describe-clusters --clusters $clusterName --region $Region --output json 2>$null | ConvertFrom-Json
    if ($cluster.clusters -and $cluster.clusters.Count -gt 0 -and $cluster.clusters[0].status -eq "ACTIVE") {
        Write-ColorMessage "✓ ECSクラスタ '$clusterName' が存在します"
        $clust = $cluster.clusters[0]
        Write-Host "  ARN: $($clust.clusterArn)"
        Write-Host "  ステータス: $($clust.status)"
        Write-Host "  アクティブサービス数: $($clust.activeServicesCount)"
        Write-Host "  実行中タスク数: $($clust.runningTasksCount)"
        
        if ($Delete) {
            Write-WarningMessage "ECSクラスタ '$clusterName' を削除中..."
            
            # タスク定義の登録解除（最新10バージョン）
            try {
                $taskDefs = aws ecs list-task-definitions --family-prefix countdown-test --region $Region --output json 2>$null | ConvertFrom-Json
                if ($taskDefs.taskDefinitionArns) {
                    foreach ($taskDefArn in $taskDefs.taskDefinitionArns | Select-Object -Last 10) {
                        aws ecs deregister-task-definition --task-definition $taskDefArn --region $Region > $null
                        Write-InfoMessage "  タスク定義 $taskDefArn を登録解除しました"
                    }
                }
            } catch {}
            
            aws ecs delete-cluster --cluster $clusterName --region $Region
            Write-ColorMessage "ECSクラスタが削除されました"
        }
    } else {
        Write-InfoMessage "ECSクラスタ '$clusterName' は存在しません"
    }
} catch {
    Write-InfoMessage "ECSクラスタ '$clusterName' は存在しません"
}

# 6. 一時ファイルの確認・削除
Write-InfoMessage ""
Write-InfoMessage "=== 一時ファイル ==="
$tempFiles = @(
    "codebuild-trust-policy.json",
    "ecs-task-trust-policy.json", 
    "codebuild-service-role-policy-updated.json",
    "codebuild\project-updated.json",
    "ecs\task-definition-updated.json"
)

foreach ($file in $tempFiles) {
    if (Test-Path $file) {
        Write-ColorMessage "✓ 一時ファイル '$file' が存在します"
        if ($Delete) {
            Remove-Item $file -Force
            Write-ColorMessage "ファイルを削除しました: $file"
        }
    } else {
        Write-InfoMessage "一時ファイル '$file' は存在しません"
    }
}

Write-InfoMessage ""
if ($Delete) {
    Write-ColorMessage "=== 削除処理完了 ==="
} else {
    Write-ColorMessage "=== 確認処理完了 ==="
    Write-InfoMessage ""
    Write-WarningMessage "リソースを削除する場合は -Delete スイッチを使用してください:"
    Write-InfoMessage "  .\cleanup-resources.ps1 -Delete"
    Write-InfoMessage "  .\cleanup-resources.ps1 -Delete -Force  # 確認なしで削除"
}
