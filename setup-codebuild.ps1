# AWS CodeBuild & CodeDeploy �N�C�b�N�X�^�[�g�X�N���v�g
# �y�p�~�z���̃X�N���v�g�͔p�~����܂���
# �蓮�Z�b�g�A�b�v�菇���g�p���Ă�������: docs/�蓮�Z�b�g�A�b�v�菇.md

Write-Host "���̃X�N���v�g�͔p�~����܂����B" -ForegroundColor Red
Write-Host "�蓮�Z�b�g�A�b�v�菇���g�p���Ă�������:" -ForegroundColor Yellow
Write-Host "  docs/�蓮�Z�b�g�A�b�v�菇.md" -ForegroundColor Cyan
Write-Host ""
Write-Host "���\�[�X�̊m�F�E�폜�ɂ͈ȉ��̃c�[�����g�p���Ă�������:" -ForegroundColor Yellow
Write-Host "  .\cleanup-resources.ps1          # ���\�[�X�m�F" -ForegroundColor Cyan
Write-Host "  .\cleanup-resources.ps1 -Delete  # ���\�[�X�폜" -ForegroundColor Cyan
exit 1

# �F�t�����b�Z�[�W�o�͊֐�
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

Write-ColorMessage "=== AWS CodeBuild & CodeDeploy �Z�b�g�A�b�v�J�n ==="

# AWS CLI �̊m�F
Write-InfoMessage "AWS CLI �o�[�W�������m�F��..."
try {
    $awsVersion = aws --version
    Write-ColorMessage "AWS CLI: $awsVersion"
} catch {
    Write-ErrorMessage "AWS CLI ���C���X�g�[������Ă��܂���B���AWS CLI���C���X�g�[�����Ă��������B"
    exit 1
}

# AWS�F�؏��̊m�F
Write-InfoMessage "AWS�F�؏����m�F��..."
try {
    $identityJson = aws sts get-caller-identity --output json
    $identity = $identityJson | ConvertFrom-Json
    Write-ColorMessage "�F�؍ς� AWS Account: $($identity.Account)"
    Write-ColorMessage "�F�؍ς� User/Role: $($identity.Arn)"
} catch {
    Write-ErrorMessage "AWS�F�؂��ݒ肳��Ă��܂���B'aws configure' �����s���Ă��������B"
    exit 1
}

# 1. ECR���|�W�g���쐬
Write-InfoMessage "ECR���|�W�g�����쐬��..."
try {
    aws ecr create-repository --repository-name $RepositoryName --region $Region --output table
    Write-ColorMessage "ECR���|�W�g�� '$RepositoryName' ���쐬����܂���"
} catch {
    Write-InfoMessage "ECR���|�W�g���͊��ɑ��݂��Ă���\��������܂��i�G���[�𖳎��j"
}

# 2. CloudWatch Logs �O���[�v�쐬
Write-InfoMessage "CloudWatch Logs�O���[�v���쐬��..."
try {
    aws logs create-log-group --log-group-name "/ecs/countdown-test" --region $Region
    aws logs create-log-group --log-group-name "/aws/codebuild/windows-countdown-build" --region $Region
    Write-ColorMessage "CloudWatch Logs�O���[�v���쐬����܂���"
} catch {
    Write-InfoMessage "CloudWatch Logs�O���[�v�͊��ɑ��݂��Ă���\��������܂��i�G���[�𖳎��j"
}

# 3. IAM���[���쐬
Write-InfoMessage "IAM���[�����쐬��..."

# CodeBuild �T�[�r�X���[���p�M���|���V�[
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

# CodeBuild �T�[�r�X���[���쐬
try {
    $codeBuildTrustPolicy | Out-File -FilePath "codebuild-trust-policy.json" -Encoding UTF8
    aws iam create-role --role-name "codebuild-windows-countdown-service-role" --assume-role-policy-document file://codebuild-trust-policy.json --region $Region
    Write-ColorMessage "CodeBuild �T�[�r�X���[�����쐬����܂���"
    
    # �|���V�[�̃A�^�b�`�i�ݒ�t�@�C�����X�V�j
    $policyContent = Get-Content "codebuild\codebuild-service-role-policy.json" -Raw -Encoding UTF8
    $policyContent = $policyContent -replace "ACCOUNT_ID", $AccountId
    $policyContent | Out-File -FilePath "codebuild-service-role-policy-updated.json" -Encoding UTF8
    
    aws iam put-role-policy --role-name "codebuild-windows-countdown-service-role" --policy-name "CodeBuildServiceRolePolicy" --policy-document file://codebuild-service-role-policy-updated.json
    Write-ColorMessage "CodeBuild �T�[�r�X���[���Ƀ|���V�[���A�^�b�`����܂���"
} catch {
    Write-InfoMessage "IAM���[���͊��ɑ��݂��Ă���\��������܂��i�G���[�𖳎��j"
}

# ECS Task Execution Role (�����̏ꍇ�̓X�L�b�v)
try {
    aws iam get-role --role-name ecsTaskExecutionRole --region $Region > $null
    Write-InfoMessage "ecsTaskExecutionRole �͊��ɑ��݂��܂�"
} catch {
    Write-InfoMessage "ecsTaskExecutionRole ���쐬��..."
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
    Write-ColorMessage "ecsTaskExecutionRole ���쐬����܂���"
}

# 4. �ݒ�t�@�C���̍X�V
Write-InfoMessage "�ݒ�t�@�C�����X�V��..."

# CodeBuild �v���W�F�N�g�ݒ�̍X�V
$projectConfig = Get-Content "codebuild\project.json" -Raw -Encoding UTF8
$projectConfig = $projectConfig -replace "ACCOUNT_ID", $AccountId
$projectConfig = $projectConfig -replace "countdown-test", $RepositoryName
$projectConfig | Out-File -FilePath "codebuild\project-updated.json" -Encoding UTF8

# ECS �^�X�N��`�̍X�V
$taskDefinition = Get-Content "ecs\task-definition.json" -Raw -Encoding UTF8
$taskDefinition = $taskDefinition -replace "ACCOUNT_ID", $AccountId
$taskDefinition = $taskDefinition -replace "countdown-test", $RepositoryName
$taskDefinition | Out-File -FilePath "ecs\task-definition-updated.json" -Encoding UTF8

# buildspec.yml �̍X�V�i���|�W�g��URI�̐ݒ�j
$buildspec = Get-Content "buildspec.yml" -Raw -Encoding UTF8
$repositoryUri = "$AccountId.dkr.ecr.$Region.amazonaws.com/$RepositoryName"
# buildspec.yml �ɂ͊��ϐ��Ƃ��Đݒ肳���̂ŁA�����ł͕ύX�s�v

Write-ColorMessage "�ݒ�t�@�C�����X�V����܂���"

# 5. CodeBuild�v���W�F�N�g�쐬
Write-InfoMessage "CodeBuild�v���W�F�N�g���쐬��..."
try {
    aws codebuild create-project --cli-input-json file://codebuild/project-updated.json --region $Region
    Write-ColorMessage "CodeBuild�v���W�F�N�g 'windows-countdown-build' ���쐬����܂���"
} catch {
    Write-InfoMessage "CodeBuild�v���W�F�N�g�͊��ɑ��݂��Ă���\��������܂��i�G���[�𖳎��j"
}

# 6. ECS�N���X�^�̊m�F�E�쐬
Write-InfoMessage "ECS�N���X�^���m�F��..."
try {
    aws ecs describe-clusters --clusters "windows-batch-test-cluster" --region $Region > $null
    Write-InfoMessage "ECS�N���X�^ 'windows-batch-test-cluster' �͊��ɑ��݂��܂�"
} catch {
    Write-InfoMessage "ECS�N���X�^���쐬��..."
    aws ecs create-cluster --cluster-name "windows-batch-test-cluster" --region $Region
    Write-ColorMessage "ECS�N���X�^ 'windows-batch-test-cluster' ���쐬����܂���"
}

# 7. �ꎞ�t�@�C���̍폜
Write-InfoMessage "�ꎞ�t�@�C�����폜��..."
Remove-Item -Path "codebuild-trust-policy.json" -ErrorAction SilentlyContinue
Remove-Item -Path "ecs-task-trust-policy.json" -ErrorAction SilentlyContinue
Remove-Item -Path "codebuild-service-role-policy-updated.json" -ErrorAction SilentlyContinue

Write-ColorMessage "=== �Z�b�g�A�b�v���� ==="
Write-InfoMessage ""
Write-InfoMessage "���̃X�e�b�v:"
Write-InfoMessage "1. �v���W�F�N�g�A�[�J�C�u��S3�ɃA�b�v���[�h�A�܂��̓��[�J����CodeBuild�����s"
Write-InfoMessage "2. CodeBuild�v���W�F�N�g���蓮���s:"
Write-InfoMessage "   aws codebuild start-build --project-name windows-countdown-build --region $Region"
Write-InfoMessage ""
Write-InfoMessage "3. ECS�^�X�N��`��o�^:"
Write-InfoMessage "   aws ecs register-task-definition --cli-input-json file://ecs/task-definition-updated.json --region $Region"
Write-InfoMessage ""
Write-InfoMessage "4. ECR���|�W�g��URI: $repositoryUri"
Write-InfoMessage ""
Write-ColorMessage "�Z�b�g�A�b�v������Ɋ������܂����I"
