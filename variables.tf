variable "hosts" {
  type        = any
  description = "Hosts to configure: a map of names to addresses, or to host objects with an address and optional host_key, user, port, private_key_file or jump_hosts."
}

variable "ssh_user" {
  type        = string
  default     = "root"
  description = "User to log in as."
}

variable "ssh_port" {
  type        = number
  default     = 22
  description = "SSH port."
}

variable "ssh_private_key_file" {
  type        = string
  default     = null
  description = "Path to a private key. When null, Conn3x uses the SSH agent."
}

variable "ssh_known_hosts_file" {
  type        = string
  default     = null
  description = "known_hosts file to check host keys against. When null, ~/.ssh/known_hosts."
}

variable "ssh_become" {
  type        = bool
  default     = false
  description = "Run commands as root through sudo."
}

variable "homepage_version" {
  type        = string
  default     = "v2.7.0"
  nullable    = false
  description = "Tag of the Homepage image, such as \"v2.7.0\". Change image_digest with it."

  validation {
    condition     = can(regex("^[A-Za-z0-9_][A-Za-z0-9_.-]*$", var.homepage_version))
    error_message = "homepage_version must be an image tag, such as \"v2.7.0\"."
  }
}

variable "image_digest" {
  type        = string
  default     = "sha256:19c5c09184458a41b7b5915e71463a39f36cd33540f41bdbed008791b8182d5f"
  nullable    = false
  description = "Digest of the image for homepage_version, such as \"sha256:19c5...\". Podman pulls by the digest, so a tag that moves upstream can't change what runs."

  validation {
    condition     = can(regex("^sha256:[a-f0-9]{64}$", var.image_digest))
    error_message = "image_digest must be a sha256 digest, such as \"sha256:\" followed by 64 hex digits."
  }
}

variable "image_repository" {
  type        = string
  default     = "ghcr.io/gethomepage/homepage"
  nullable    = false
  description = "Where to pull Homepage's image from, without a tag."

  validation {
    condition     = can(regex("^[a-z0-9.-]+(:[0-9]+)?(/[a-z0-9._-]+)+$", var.image_repository))
    error_message = "image_repository must be a registry and path without a tag, such as \"ghcr.io/gethomepage/homepage\"."
  }
}

variable "listen_address" {
  type        = string
  default     = "127.0.0.1"
  description = "Address Homepage listens on. The default keeps it on the host for a reverse proxy in front; \"0.0.0.0\" listens on every address."

  validation {
    condition     = can(cidrhost("${var.listen_address}/${strcontains(var.listen_address, ":") ? 128 : 32}", 0))
    error_message = "listen_address must be an IPv4 or IPv6 address, such as \"127.0.0.1\"."
  }
}

variable "port" {
  type        = number
  default     = 3000
  description = "Port Homepage listens on."

  validation {
    condition     = var.port >= 1 && var.port <= 65535 && floor(var.port) == var.port
    error_message = "port must be a whole number from 1 to 65535."
  }
}

variable "allowed_hosts" {
  type        = list(string)
  default     = []
  nullable    = false
  description = "Host names, with a port where people type one, that Homepage answers to, such as [\"home.example.com\"]. It refuses any other Host header with a 400. The address it listens on is always allowed."

  validation {
    condition     = alltrue([for h in var.allowed_hosts : can(regex("^[A-Za-z0-9.\\[\\]:-]+$", h))])
    error_message = "Each of allowed_hosts must be a host name or address, optionally with a port, such as \"home.example.com\" or \"192.168.1.20:3000\". \"*\" isn't accepted."
  }
}

variable "settings" {
  type        = any
  default     = { title = "Homepage" }
  description = "settings.yaml: a map, such as { title = \"Home\", theme = \"dark\" }, or the file's YAML as a string. See https://gethomepage.dev/configs/settings/."
}

variable "services" {
  type        = any
  default     = []
  description = "services.yaml: a list of groups, each a map of a group name to its services, or the file's YAML as a string. See https://gethomepage.dev/configs/services/."
}

variable "bookmarks" {
  type        = any
  default     = []
  description = "bookmarks.yaml: a list of groups, or the file's YAML as a string. See https://gethomepage.dev/configs/bookmarks/."
}

variable "widgets" {
  type = any
  default = [
    { resources = { cpu = true, memory = true, disk = "/" } },
    { search = { provider = "duckduckgo", target = "_blank" } },
  ]
  description = "widgets.yaml: the information widgets along the top, as a list, or the file's YAML as a string. The default is Homepage's own sample. See https://gethomepage.dev/widgets/."
}

variable "environment" {
  type        = map(string)
  default     = {}
  ephemeral   = true
  sensitive   = true
  nullable    = false
  description = "More of Homepage's environment variables, such as { HOMEPAGE_VAR_PROXMOX_PASSWORD = \"...\" }, which the config files can use as {{HOMEPAGE_VAR_PROXMOX_PASSWORD}}. They go in a root-only env file and never reach the plan or state."

  validation {
    condition     = alltrue([for k, v in var.environment : can(regex("^[A-Za-z_][A-Za-z0-9_]*$", k)) && !strcontains(v, "\n")])
    error_message = "environment maps variable names, such as HOMEPAGE_VAR_API_KEY, to values on one line."
  }

  validation {
    condition     = length(setintersection(keys(var.environment), ["HOSTNAME", "PORT", "HOMEPAGE_ALLOWED_HOSTS", "HOMEPAGE_CONFIG_DIR"])) == 0
    error_message = "Set the listen address, port and allowed hosts with their own inputs."
  }
}
