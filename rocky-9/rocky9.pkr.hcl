packer {
  required_plugins {
    qemu = {
      version = ">= 1.1.3"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

variable "cloud" {
  type    = string
  default = "aws"
  validation {
    condition     = contains(["aws", "azure", "google", "oracle"], var.cloud)
    error_message = "The cloud variable must be one of: aws, azure, google, oracle."
  }
}

variable "accelerator" {
  type    = string
  default = "kvm"
  validation {
    condition     = contains(["kvm", "tcg", "hvf"], var.accelerator)
    error_message = "The accelerator variable must be one of: kvm, tcg, hvf."
  }
}

variable "disk_size_gb" {
  type    = number
  default = 119
  validation {
    condition     = var.disk_size_gb >= 8 && floor(var.disk_size_gb) == var.disk_size_gb
    error_message = "The disk_size_gb variable must be a whole number of GiB, at least 8."
  }
}

variable "root_gb" {
  type    = number
  default = 50
  validation {
    condition     = var.root_gb >= 1 && floor(var.root_gb) == var.root_gb
    error_message = "The root_gb variable must be a whole number of GiB, at least 1."
  }
}

variable "var_gb" {
  type    = number
  default = 15
  validation {
    condition     = var.var_gb >= 1 && floor(var.var_gb) == var.var_gb
    error_message = "The var_gb variable must be a whole number of GiB, at least 1."
  }
}

variable "var_log_gb" {
  type    = number
  default = 8
  validation {
    condition     = var.var_log_gb >= 1 && floor(var.var_log_gb) == var.var_log_gb
    error_message = "The var_log_gb variable must be a whole number of GiB, at least 1."
  }
}

variable "var_log_audit_gb" {
  type    = number
  default = 3
  validation {
    condition     = var.var_log_audit_gb >= 1 && floor(var.var_log_audit_gb) == var.var_log_audit_gb
    error_message = "The var_log_audit_gb variable must be a whole number of GiB, at least 1."
  }
}

variable "var_tmp_gb" {
  type    = number
  default = 5
  validation {
    condition     = var.var_tmp_gb >= 1 && floor(var.var_tmp_gb) == var.var_tmp_gb
    error_message = "The var_tmp_gb variable must be a whole number of GiB, at least 1."
  }
}

variable "tmp_gb" {
  type    = number
  default = 8
  validation {
    condition     = var.tmp_gb >= 1 && floor(var.tmp_gb) == var.tmp_gb
    error_message = "The tmp_gb variable must be a whole number of GiB, at least 1."
  }
}

variable "cpus" {
  type    = number
  default = 4
}

variable "memory_mb" {
  type    = number
  default = 8192
}

variable "output_directory" {
  type    = string
  default = "output-rocky9"
}

variable "serial_log" {
  type    = string
  default = "serial.log"
}

variable "image_name" {
  type    = string
  default = ""
}

variable "iso_url" {
  type    = string
  default = ""
}

variable "iso_checksum" {
  type    = string
  default = ""
}

variable "efi_firmware_code" {
  type    = string
  default = ""
}

variable "efi_firmware_vars" {
  type    = string
  default = ""
}

variable "boot_wait" {
  type    = string
  default = ""
}

variable "shutdown_timeout" {
  type    = string
  default = ""
}

locals {
  iso_url           = var.iso_url != "" ? var.iso_url : "https://download.rockylinux.org/pub/rocky/9/isos/x86_64/Rocky-9.8-x86_64-minimal.iso"
  iso_checksum      = var.iso_checksum != "" ? var.iso_checksum : "sha256:d338032cd1cdd41c67139f2f71b4c832c8e4a21943106519db9c7137df7a63d4"
  efi_firmware_code = var.efi_firmware_code != "" ? var.efi_firmware_code : "/usr/share/OVMF/OVMF_CODE_4M.fd"
  efi_firmware_vars = var.efi_firmware_vars != "" ? var.efi_firmware_vars : "/usr/share/OVMF/OVMF_VARS_4M.fd"
  cpu_model         = var.accelerator == "tcg" ? "max" : "host"
  boot_wait         = var.boot_wait != "" ? var.boot_wait : (var.accelerator == "tcg" ? "45s" : "15s")
  shutdown_timeout  = var.shutdown_timeout != "" ? var.shutdown_timeout : (var.accelerator == "tcg" ? "300m" : "90m")
  image_name        = var.image_name != "" ? var.image_name : "rocky9-separate-partitions-${var.cloud}-x86_64"
  console_args      = "console=tty0 console=ttyS0,115200n8"

  partitions = templatefile("${abspath(path.root)}/partitions.pkrtpl.hcl", {
    root_mb          = var.root_gb * 1024
    var_mb           = var.var_gb * 1024
    var_log_mb       = var.var_log_gb * 1024
    var_log_audit_mb = var.var_log_audit_gb * 1024
    var_tmp_mb       = var.var_tmp_gb * 1024
    tmp_mb           = var.tmp_gb * 1024
  })

  ks_content = templatefile("${abspath(path.root)}/http/ks-${var.cloud}.cfg.pkrtpl.hcl", {
    partitions = local.partitions
  })
}

source "qemu" "rocky9" {
  iso_url           = local.iso_url
  iso_checksum      = local.iso_checksum
  qemu_binary       = "qemu-system-x86_64"
  machine_type      = "q35"
  accelerator       = var.accelerator
  cpu_model         = local.cpu_model
  cpus              = var.cpus
  memory            = var.memory_mb
  disk_size         = "${var.disk_size_gb}G"
  format            = "raw"
  output_directory  = var.output_directory
  vm_name           = "${local.image_name}.raw"
  efi_firmware_code = local.efi_firmware_code
  efi_firmware_vars = local.efi_firmware_vars
  efi_drop_efivars  = true
  http_content = {
    "/ks-${var.cloud}.cfg" = local.ks_content
  }
  communicator     = "none"
  shutdown_timeout = local.shutdown_timeout
  boot_wait        = local.boot_wait
  headless         = true
  vnc_bind_address = "127.0.0.1"
  net_device       = "virtio-net"

  boot_command = [
    "<up>",
    "e",
    "<down><down><end>",
    " inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ks-${var.cloud}.cfg inst.gpt ${local.console_args}",
    "<f10>"
  ]

  qemuargs = [
    ["-serial", "file:${var.serial_log}"],
    ["-boot", "order=d,menu=on"]
  ]
}

build {
  name    = "rocky9-separate-partitions"
  sources = ["source.qemu.rocky9"]

  post-processor "shell-local" {
    environment_vars = [
      "CLOUD=${var.cloud}",
      "RAW=${var.output_directory}/${local.image_name}.raw",
      "OUT=${var.output_directory}",
      "NAME=${local.image_name}",
    ]
    script = "${abspath(path.root)}/../scripts/convert-image.sh"
  }
}
