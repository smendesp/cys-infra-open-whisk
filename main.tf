terraform {
  required_version = ">= 1.0"
  required_providers {
    null = { source = "hashicorp/null", version = "~> 3.0" }
  }
  backend "local" {
    path = "terraform.tfstate"
  }
}

resource "null_resource" "render_manifests" {
  triggers = {
    manifests_sha = sha1(join("", [
      for f in sort(fileset("${path.module}/manifests", "*.yaml")) :
      filesha256("${path.module}/manifests/${f}")
    ]))
    vars_sha = sha1(join(",", [
      var.openwhisk_api_host,
      var.openwhisk_api_host_port,
      var.openwhisk_auth_system_key,
      var.openwhisk_auth_guest_key,
      var.openwhisk_db_password
    ]))
  }

  provisioner "local-exec" {
    command = <<-SCRIPT
      set -euo pipefail
      RENDERED_DIR="${path.module}/deploy"
      rm -rf "$RENDERED_DIR"
      mkdir -p "$RENDERED_DIR"

      export OPENWHISK_API_HOST="${var.openwhisk_api_host}"
      export OPENWHISK_API_HOST_PORT="${var.openwhisk_api_host_port}"
      export OPENWHISK_AUTH_SYSTEM_KEY="${var.openwhisk_auth_system_key}"
      export OPENWHISK_AUTH_GUEST_KEY="${var.openwhisk_auth_guest_key}"
      export OPENWHISK_DB_PASSWORD="${var.openwhisk_db_password}"

      SUBST_VARS='$${OPENWHISK_API_HOST} $${OPENWHISK_API_HOST_PORT} $${OPENWHISK_AUTH_SYSTEM_KEY} $${OPENWHISK_AUTH_GUEST_KEY} $${OPENWHISK_DB_PASSWORD}'

      for f in "${path.module}/manifests"/*.yaml; do
        envsubst "$SUBST_VARS" < "$f" > "$RENDERED_DIR/$(basename "$f")"
      done

      echo "Manifests renderizados em $RENDERED_DIR"
      ls -la "$RENDERED_DIR"
    SCRIPT
    interpreter = ["bash", "-c"]
    working_dir = path.module
  }
}
