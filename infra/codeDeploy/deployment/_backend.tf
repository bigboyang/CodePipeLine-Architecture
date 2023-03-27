terraform {
  backend "s3" {
    bucket      = "kkc-terraform-backend"
    key         = "dev/apne2/codedeploy/deployment/terraform.tfstate"
    region      = "ap-northeast-2"
#    role_arn    = "{ASSUMED_ROLE}"
    max_retries = 3
  }
}
