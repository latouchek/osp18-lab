terraform {
  required_providers {
    libvirt = {
      source = "dmacvicar/libvirt"
    }
  }
}

# instance the provider
provider "libvirt" {
  uri = "qemu:///system"
}

resource "libvirt_volume" "fatdisk" {
  count = 3
  name  = "fatdisk-osp-compute-${count.index}"
  pool  = "default"
  size  = 130000000000
}

resource "libvirt_domain" "osp-compute" {
  count  = 3
  name   = "osp-compute-${count.index}"
  memory = "32000"
  arch   = "x86_64"
  machine = "q35"
  xml {
    xslt = file("cdrom-model.xsl")
  }
  vcpu = 8
  cpu {
    mode = "host-passthrough"
  }
  running = false
  boot_device {
    dev = ["hd", "cdrom"]
  }

  # network_interface {
  #   network_name = "lab-net"
  #   mac = format("be:bb:cc:12:82:%02x", count.index)
  # }
  network_interface {
    network_name = "osp-trunk-network"
    mac = format("bc:bb:cc:12:82:%02x", count.index)
  }
  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }
  console {
    type        = "pty"
    target_type = "virtio"
    target_port = "1"
  }
  disk {
    volume_id = libvirt_volume.fatdisk[count.index].id
  }
  disk {
    file = "/var/lib/libvirt/images/dummy.iso"
  }
  graphics {
    type        = "vnc"
    listen_type = "address"
    autoport    = true
  }
}

output "osp-compute_UUIDs" {
  value = [for instance in libvirt_domain.osp-compute : instance.id]
}
