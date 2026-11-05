variable "port" {
  type    = number
  default = 2222
}

# Null takes the circuit's defaults. CI sets an older pair first, to test an
# upgrade.
variable "homepage_version" {
  type    = string
  default = null
}

variable "image_digest" {
  type    = string
  default = null
}

# Example value only. A real one would be an API key for a widget.
variable "greeting" {
  type      = string
  default   = "hello-from-an-env-file"
  ephemeral = true
  sensitive = true
}

module "homepage" {
  source = "../.."

  hosts                = { box = "127.0.0.1" }
  ssh_port             = var.port
  ssh_private_key_file = "./id_ed25519"
  ssh_known_hosts_file = "./known_hosts"

  homepage_version = var.homepage_version
  image_digest     = var.image_digest

  settings = { title = "Conn3x example" }

  # Homepage checks each siteMonitor from the server and shows its status.
  services = [
    {
      "This host" = [
        { Homepage = { href = "http://127.0.0.1:3000", description = "{{HOMEPAGE_VAR_GREETING}}", siteMonitor = "http://127.0.0.1:3000" } },
        { Closed = { href = "http://127.0.0.1:9", description = "Nothing listens here", siteMonitor = "http://127.0.0.1:9" } },
      ]
    },
  ]

  # A file's YAML can go in as it is, too.
  bookmarks = <<-EOT
    - Conn3x:
        - Docs:
            - abbr: C3
              href: https://conn3x.org
  EOT

  environment = { HOMEPAGE_VAR_GREETING = var.greeting }
}
