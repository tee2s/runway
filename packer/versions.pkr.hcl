packer {
  required_version = ">= 1.14.0"

  required_plugins {
    amazon = {
      version = "~> 1.8.0"
      source  = "github.com/hashicorp/amazon"
    }
  }
}
