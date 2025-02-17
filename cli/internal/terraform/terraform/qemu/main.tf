terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.7.1"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "2.25.0"
    }
  }
}

provider "libvirt" {
  uri = var.libvirt_uri
}

provider "docker" {
  host = "unix:///var/run/docker.sock"
}

resource "random_password" "initSecret" {
  length           = 32
  special          = true
  override_special = "_%@"
}
resource "docker_image" "qemu_metadata" {
  name         = var.metadata_api_image
  keep_locally = true
}

resource "docker_container" "qemu_metadata" {
  name         = "${var.name}-qemu-metadata"
  image        = docker_image.qemu_metadata.image_id
  network_mode = "host"
  rm           = true
  command = [
    "--network",
    "${var.name}-network",
    "--libvirt-uri",
    "${var.metadata_libvirt_uri}",
    "--initsecrethash",
    "${random_password.initSecret.bcrypt_hash}",
  ]
  mounts {
    source = abspath(var.libvirt_socket_path)
    target = "/var/run/libvirt/libvirt-sock"
    type   = "bind"
  }
}



module "control_plane" {
  source           = "./modules/instance_group"
  role             = "control-plane"
  amount           = var.control_plane_count
  vcpus            = var.vcpus
  memory           = var.memory
  state_disk_size  = var.state_disk_size
  cidr             = "10.42.1.0/24"
  network_id       = libvirt_network.constellation.id
  pool             = libvirt_pool.cluster.name
  boot_mode        = var.constellation_boot_mode
  boot_volume_id   = libvirt_volume.constellation_os_image.id
  kernel_volume_id = local.kernel_volume_id
  initrd_volume_id = local.initrd_volume_id
  kernel_cmdline   = local.kernel_cmdline
  machine          = var.machine
  firmware         = var.firmware
  nvram            = var.nvram
  name             = var.name
}

module "worker" {
  source           = "./modules/instance_group"
  role             = "worker"
  amount           = var.worker_count
  vcpus            = var.vcpus
  memory           = var.memory
  state_disk_size  = var.state_disk_size
  cidr             = "10.42.2.0/24"
  network_id       = libvirt_network.constellation.id
  pool             = libvirt_pool.cluster.name
  boot_mode        = var.constellation_boot_mode
  boot_volume_id   = libvirt_volume.constellation_os_image.id
  kernel_volume_id = local.kernel_volume_id
  initrd_volume_id = local.initrd_volume_id
  kernel_cmdline   = var.constellation_cmdline
  machine          = var.machine
  firmware         = var.firmware
  nvram            = var.nvram
  name             = var.name
}

resource "libvirt_pool" "cluster" {
  name = "${var.name}-storage-pool"
  type = "dir"
  path = "/var/lib/libvirt/images"
}

resource "libvirt_volume" "constellation_os_image" {
  name   = "${var.name}-node-image"
  pool   = libvirt_pool.cluster.name
  source = var.constellation_os_image
  format = var.image_format
}

resource "libvirt_volume" "constellation_kernel" {
  name   = "${var.name}-kernel"
  pool   = libvirt_pool.cluster.name
  source = var.constellation_kernel
  format = "raw"
  count  = var.constellation_boot_mode == "direct-linux-boot" ? 1 : 0
}

resource "libvirt_volume" "constellation_initrd" {
  name   = "${var.name}-initrd"
  pool   = libvirt_pool.cluster.name
  source = var.constellation_initrd
  format = "raw"
  count  = var.constellation_boot_mode == "direct-linux-boot" ? 1 : 0
}

resource "libvirt_network" "constellation" {
  name      = "${var.name}-network"
  mode      = "nat"
  addresses = ["10.42.0.0/16"]
  dhcp {
    enabled = true
  }
  dns {
    enabled = true
  }
}

locals {
  kernel_volume_id = var.constellation_boot_mode == "direct-linux-boot" ? libvirt_volume.constellation_kernel[0].id : null
  initrd_volume_id = var.constellation_boot_mode == "direct-linux-boot" ? libvirt_volume.constellation_initrd[0].id : null
  kernel_cmdline   = var.constellation_boot_mode == "direct-linux-boot" ? var.constellation_cmdline : null
}
