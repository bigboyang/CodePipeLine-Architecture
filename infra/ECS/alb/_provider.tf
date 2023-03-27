provider "aws" {
  region = local.region

#  assume_role {
#    role_arn     = "{ASSUMED_ROLE}"
#    session_name = "{SESSION_NAME}"
#  }
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 3.29.0, >= 4.0.0, >= 4.20.0"
    }
    template = {
      source  = "hashicorp/template"
      version = "2.2.0"
    }
  }
}
