variable "project" {
  description = "Nom du projet, utilisé dans le nom des ressources"
  type        = string
}

variable "environment" {
  description = "Environnement déployé"
  type        = string

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment doit valoir dev ou prod."
  }
}

variable "region" {
  description = "Région AWS, passée au script de démarrage"
  type        = string
  default     = "us-east-1"
}

variable "vpc_id" {
  description = "VPC dans lequel déployer la pile"
  type        = string
}

variable "subnet_ids" {
  description = "Subnets publics, au moins deux zones de disponibilité"
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "Il faut au moins deux subnets, dans deux zones différentes."
  }
}

variable "ami_id" {
  description = "AMI des instances (Amazon Linux 2023)"
  type        = string
}

variable "instance_type" {
  description = "Type d'instance EC2"
  type        = string
  default     = "t3.micro"
}

variable "instance_profile_name" {
  description = "Profil IAM des instances (imposé par le Learner Lab)"
  type        = string
  default     = "LabInstanceProfile"
}

variable "secret_parameter_name" {
  description = "Chemin du secret de cet environnement dans Parameter Store"
  type        = string
}

variable "app_message" {
  description = "Titre affiché sur la page d'accueil"
  type        = string
  default     = "Bienvenue sur NovaSphere"
}

variable "min_size" {
  description = "Nombre minimum d'instances dans l'ASG"
  type        = number
  default     = 2

  validation {
    condition     = var.min_size >= 2
    error_message = "Le cahier des charges impose au moins 2 instances."
  }
}

variable "max_size" {
  description = "Nombre maximum d'instances dans l'ASG"
  type        = number
  default     = 4
}

variable "desired_capacity" {
  description = "Nombre d'instances souhaité"
  type        = number
  default     = 2
}
