variable "openwhisk_api_host" {
  description = "Hostname externo da API OpenWhisk (ex: openwhisk.cys.com.br)"
  type        = string
}

variable "openwhisk_api_host_port" {
  description = "Porta da API OpenWhisk via NodePort"
  type        = string
  default     = "31001"
}

variable "openwhisk_auth_system_key" {
  description = "Chave de autenticacao do sistema (formato uuid:secret)"
  type        = string
  sensitive   = true
}

variable "openwhisk_auth_guest_key" {
  description = "Chave de autenticacao guest (deve ser diferente da system)"
  type        = string
  sensitive   = true
}

variable "openwhisk_db_password" {
  description = "Senha do CouchDB para usuario whisk_admin"
  type        = string
  sensitive   = true
}
