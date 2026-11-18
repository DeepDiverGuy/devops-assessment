variable "region" {
  type    = string
  default = "ap-southeast-1"
}

variable "environment" {
  type        = string
  description = "Environment name (staging or prod)"
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "app_port" {
  type    = number
  default = 8080
}

variable "allowed_cidr" {
  type        = list(string)
  description = "CIDR blocks allowed to reach the app port"
  default     = ["0.0.0.0/0"]
}

variable "image_repo" {
  type    = string
  default = "ghcr.io/deepdiverguy/devops-assessment"
}

variable "image_tag" {
  type        = string
  description = "Image tag deployed at first boot; later releases go through the CD pipeline"
  default     = "1.0.0"
}

variable "log_retention_days" {
  type = number
}
