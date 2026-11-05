locals {
  image  = "${var.image_repository}:${var.homepage_version}@${var.image_digest}"
  config = "/var/lib/homepage/config"

  local_host = lookup({ "0.0.0.0" = "127.0.0.1", "::" = "[::1]" }, var.listen_address, strcontains(var.listen_address, ":") ? "[${var.listen_address}]" : var.listen_address)
  local_url  = "http://${local.local_host}:${var.port}"

  # Waits for a listener on the port, read from /proc so the host needs no ss.
  wait_port = "for _ in $(seq 900); do grep -qE ':${format("%04X", var.port)} [0-9A-F]+:[0-9A-F]{4} 0A ' /proc/net/tcp /proc/net/tcp6 2>/dev/null && exit 0; sleep 1; done; echo 'Nothing listened on port ${var.port} in 15 minutes. See journalctl -u homepage.' >&2; exit 1"

  # A string is written as it is, so a file from an existing install can be
  # pasted in. Anything else is converted to YAML.
  files = {
    "settings.yaml"  = { value = var.settings, list = false }
    "services.yaml"  = { value = var.services, list = true }
    "bookmarks.yaml" = { value = var.bookmarks, list = true }
    "widgets.yaml"   = { value = var.widgets, list = true }
  }
  content = { for f, v in local.files : f => "# Written by Conn3x. Changes here are overwritten on the next apply.\n${try(tostring(v.value), yamlencode(v.value))}" }

  # Each file is parsed by the js-yaml in the image, with the schema Homepage
  # loads it with, and must hold a list or a map as Homepage expects. The
  # file comes in on stdin, so the container needs no mount and no network.
  validate = { for f, v in local.files : f => join(" ", [
    "podman run --rm -i --network none --entrypoint node ${local.image} -e",
    "'const y = require(\"/app/node_modules/js-yaml\"); const d = y.load(require(\"fs\").readFileSync(0, \"utf8\"), { schema: y.CORE_SCHEMA.withTags(y.timestampTag, y.mergeTag, y.legacyMapTag) }); if (d != null && Array.isArray(d) !== ${v.list}) { console.error(\"${f} must hold a ${v.list ? "list" : "map"}.\"); process.exit(1); }'",
    "< %s",
  ]) }
}

circuit "homepage" {
  hosts = var.hosts

  ssh {
    user             = var.ssh_user
    port             = var.ssh_port
    private_key_file = var.ssh_private_key_file
    known_hosts_file = var.ssh_known_hosts_file
    become           = var.ssh_become
  }

  # The image runs as root, so nobody else on the host needs to get in.
  step "dir" {
    directory {
      path  = "/var/lib/homepage"
      owner = "root"
      group = "root"
      mode  = "0700"
    }
  }

  step "config_dir" {
    directory {
      path  = local.config
      owner = "root"
      group = "root"
      mode  = "0700"
    }
  }
}

# Homepage runs from its official image as a Quadlet unit, on the host's
# network so its site monitors and widgets reach services on 127.0.0.1.
# HOSTNAME and PORT decide where it listens.
module "podman" {
  source = "github.com/conn3xorg/circuit-podman?ref=v0.1.0"

  depends_on = [conn3x_directory.homepage__config_dir]

  hosts                = var.hosts
  ssh_user             = var.ssh_user
  ssh_port             = var.ssh_port
  ssh_private_key_file = var.ssh_private_key_file
  ssh_known_hosts_file = var.ssh_known_hosts_file
  ssh_become           = var.ssh_become

  containers = {
    homepage = {
      image   = local.image
      volumes = ["${local.config}:/app/config:Z"]
      environment = {
        HOSTNAME               = var.listen_address
        PORT                   = tostring(var.port)
        HOMEPAGE_ALLOWED_HOSTS = join(",", concat(["${local.local_host}:${var.port}"], var.allowed_hosts))
      }
      extra = ["Network=host"]
    }
  }
  secrets = {
    homepage = var.environment
  }
}

circuit "config" {
  hosts = var.hosts

  ssh {
    user             = var.ssh_user
    port             = var.ssh_port
    private_key_file = var.ssh_private_key_file
    known_hosts_file = var.ssh_known_hosts_file
    become           = var.ssh_become
  }

  # After the container, since the check runs the image. Homepage copies its
  # samples in for any file that's missing as it starts, and these replace
  # them.
  step "file" {
    depends_on = [module.podman]
    for_each   = local.content
    file {
      path     = "${local.config}/${item.key}"
      content  = item.value
      validate = local.validate[item.key]
      owner    = "root"
      group    = "root"
      mode     = "0600"
    }
  }

  # A changed file restarts Homepage, so it starts again from the new files.
  # Then it waits for the port: the wait_for below was already met before the
  # restart. A change to the environment alone is caught by the next plan.
  step "restart" {
    command {
      command  = "systemctl restart homepage.service && ${local.wait_port}"
      triggers = sha256(jsonencode([local.content, local.image, var.listen_address, var.port, var.allowed_hosts]))
    }
  }

  step "port" {
    wait_for {
      port    = var.port
      timeout = "15m"
    }
  }
}
