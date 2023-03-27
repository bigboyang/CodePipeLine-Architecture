terraform {
  backend "s3" {
    bucket      = "kkc-terraform-backend"
    key         = "dev/apne2/ec2/bastion/terraform.tfstate"
    region      = "ap-northeast-2"
#    role_arn    = "{ASSUMED_ROLE}"
    max_retries = 3
  }
}
