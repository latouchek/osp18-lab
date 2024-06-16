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
variable "worker" {
    type = list(string)
    default = ["ocp4-worker0", "ocp4-worker1", "ocp4-worker2"]
  }
variable "master" {
     type = list(string)
     default = ["ocp4-master1", "ocp4-master2","ocp4-master3"]
   }

variable "worker-ht" {
    type = list(string)
    default = ["ocp4-worker1-ht"]
  }
####workers
resource "libvirt_volume" "fatdisk-workers" {
  # name           = "fatdisk-${element(var.worker, count.index)}"
  name           = "fatdisk-${element(var.worker, count.index)}"
  pool           = "default"
  size           = 130000000000
  count = "${length(var.worker)}"
}
resource "libvirt_volume" "volume-mon-workers" {
  name   = "volume-mon-${element(var.worker, count.index)}"
  pool   = "default"
  size   = "30000000000"
  format = "qcow2"
  count = "${length(var.worker)}"
}
resource "libvirt_volume" "volume-osd1-workers" {
  name   = "volume-osd1-${element(var.worker, count.index)}"
  pool   = "default"
  size   = "30000000000"
  format = "qcow2"
  count = "${length(var.worker)}"
}
resource "libvirt_volume" "volume-osd2-workers" {
  name   = "volume-osd2-${element(var.worker, count.index)}"
  pool   = "default"
  size   = "30000000000"
  format = "qcow2"
  count = "${length(var.worker)}"
}
resource "libvirt_volume" "volume-osd3-workers" {
  name   = "volume-osd3-${element(var.worker, count.index)}"
  pool   = "default"
  size   = "80000000000"
  format = "qcow2"
  count = "${length(var.worker)}"
}

resource "libvirt_domain" "workers" {
  name   = "${element(var.worker, count.index)}"
  memory = "75000"
  vcpu   = 26
  cpu   {
  mode = "host-passthrough"
  }
  running = false
  boot_device {
      dev = ["hd","cdrom"]
    }
  network_interface {
    network_name = "lab-net"
    mac = "AA:BB:CC:11:42:2${count.index}"
   }
   network_interface {
     network_name = "lab-net"
     mac = "AA:BB:CC:11:42:5${count.index}"
   }
   network_interface {
     network_name = "osp-trunk-network"
     mac = "AA:BB:CC:11:42:6${count.index}"
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
    volume_id = "${element(libvirt_volume.fatdisk-workers.*.id, count.index)}"
  }
  disk {
      file = "/var/lib/libvirt/images/discovery_image.iso"
    }
  disk {
    volume_id = "${element(libvirt_volume.volume-mon-workers.*.id, count.index)}"
  }
  disk {
    volume_id = "${element(libvirt_volume.volume-osd1-workers.*.id, count.index)}"
  }
  disk {
    volume_id = "${element(libvirt_volume.volume-osd2-workers.*.id, count.index)}"
  }
  disk {
    volume_id = "${element(libvirt_volume.volume-osd3-workers.*.id, count.index)}"
  }
  graphics {
    type        = "vnc"
    listen_type = "address"
    autoport    = true
  }
  count = "${length(var.worker)}"
}

