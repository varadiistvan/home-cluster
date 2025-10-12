variable "copyparty_ah_iterations" {
  type    = number
  default = 424242
}

# Generate a stable, stateful salt (letters/digits only so YAML is painless).
resource "random_password" "copyparty_ah_salt" {
  length  = 32
  special = false
}

# Optional: choose Python executable
variable "python_exe" {
  type    = string
  default = "python3"
}

locals {
  users = {
    stevev = var.copyparty_password
    geeki  = var.geeki_master
  }
}

# Helper script reproducing your _gen_sha2 (sha512 over salt + "username:password" + prev, N iters)
resource "local_file" "sha2_py" {
  filename = "${path.module}/sha2.py"
  content  = <<-PY
    #!/usr/bin/env python3
    import sys, json, base64, hashlib

    def main():
        data = json.load(sys.stdin)
        plain = data["plain"]                  # expected "username:password"
        salt = data["salt"].encode("utf-8")
        its = int(data.get("iterations") or 424242)

        bplain = plain.encode("utf-8")
        ret = b"\n"
        for _ in range(its):
            ret = hashlib.sha512(salt + bplain + ret).digest()

        out = "+" + base64.urlsafe_b64encode(ret[:24]).decode("utf-8")
        json.dump({"hash": out}, sys.stdout)

    if __name__ == "__main__":
        main()
    PY
}

# Compute hashes for each account; note we hash "username:password" since 'usernames' is enabled
data "external" "pw_hash" {
  for_each = local.users
  program  = [var.python_exe, local_file.sha2_py.filename]
  query = {
    plain      = "${each.key}:${each.value}"
    salt       = random_password.copyparty_ah_salt.result
    iterations = tostring(var.copyparty_ah_iterations)
  }
  depends_on = [local_file.sha2_py]
}

# Your ConfigMap with hashed accounts and the same random ah-salt
resource "kubernetes_config_map" "copyparty_config" {
  metadata {
    name      = "copyparty-config"
    namespace = kubernetes_namespace.apps.id
  }

  data = {
    "copyparty.conf" = <<-YAML
      [global]
      e2dsa
      e2ts
      ansi
      qr
      xff-src: lan
      rproxy: -1
      usernames
      ah-alg: sha2,${var.copyparty_ah_iterations}
      ah-salt: ${random_password.copyparty_ah_salt.result}

      [accounts]
      stevev: ${data.external.pw_hash["stevev"].result.hash}
      geeki: ${data.external.pw_hash["geeki"].result.hash}

      [/]
        ./root
        accs:
          A: stevev

      [/geeki]
        ./geeki
        accs:
          A: stevev
          A: geeki
    YAML
  }
}

resource "helm_release" "copyparty" {
  name       = "copyparty"
  namespace  = kubernetes_namespace.apps.id
  repository = "oci://ghcr.io/danielr1996"
  chart      = "copyparty"
  values     = [file("${path.module}/values/copyparty-values.yaml")]
  version    = "0.5.1"

  set = [{
    name  = "existingConfigMap"
    value = kubernetes_config_map.copyparty_config.metadata[0].name
  }]

  lifecycle {
    ignore_changes = [metadata]
  }
}
