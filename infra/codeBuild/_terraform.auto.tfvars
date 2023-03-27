env   = "dev"
name  = "go-codebuild"
owner = "kkc"
tags  = {}

# iam
# AmazonEC2ContainerRegistryPowerUser 추가
trusted_role_services = ["codebuild.amazonaws.com"]
custom_role_policy_arns = [
  "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess",
  "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess",
  "arn:aws:iam::aws:policy/AmazonVPCFullAccess",
  "arn:aws:iam::aws:policy/AmazonS3FullAccess"
]

# codebuild
codebuild_timeout   = "10"
codebuild_source_s3 = "project" # s3에서 코드빌드 프로젝트의 소스 위치
codebuild_buildspec = "deploy/buildspec.yml"
codebuild_envs = {
  compute_type    = "BUILD_GENERAL1_SMALL"
  image           = "aws/codebuild/standard:4.0"
  type            = "LINUX_CONTAINER"
  privileged_mode = true
}
codebuild_cache_type = "LOCAL"