data "terraform_remote_state" "vpc" {
  backend = "s3"
  config = {
    bucket = var.backend_s3
    key    = var.vpc_key
    region = var.region
  }
}

# target그룹용 
# data "terraform_remote_state" "ecs" {
#   backend = "s3"
#   config = {
#     bucket = var.backend_s3
#     key    = var.ecs_key
#     region = var.region
#   }
# }