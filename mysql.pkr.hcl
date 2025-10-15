packer {
  required_plugins {
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = "~> 1"
    }
  }
}

variable "mysql_version" {
  type    = string
  default = "8.4"
}

variable "image_base_url" {
  type    = string
  default = "https://cdimage.debian.org/cdimage/cloud/bullseye/daily/latest"
}

variable "image_name" {
  type    = string
  default = "debian-11-genericcloud-amd64-daily.qcow2"
}

variable "release_tag" {
  type    = string
  default = "latest"
}

variable "headless" {
  type    = bool
  default = true
}

variable "kvm" {
  type    = bool
  default = true
}

source "qemu" "debian" {
  accelerator  = var.kvm ? "kvm" : "none"
  iso_url      = "${var.image_base_url}/${var.image_name}"
  iso_checksum = "file:${var.image_base_url}/SHA512SUMS"
  http_content = {
    "/cloud-init/user-data" = file("http/cloud-init/user-data")
    "/cloud-init/meta-data" = file("http/cloud-init/meta-data")
  }
  boot_wait          = "5s"
  disk_image         = true
  disk_compression   = true
  skip_compaction    = false
  disk_detect_zeroes = "unmap"
  disk_discard       = "unmap"
  disk_interface     = "virtio"
  net_device         = "virtio-net"
  qemuargs           = [["-smbios", "type=1,serial=ds=nocloud-net;s=http://{{ .HTTPIP }}:{{ .HTTPPort }}/cloud-init/"]]
  ssh_username       = "debian"
  ssh_password       = "packer"
  ssh_timeout        = "5m"
  shutdown_command   = "echo 'packer' | sudo -S shutdown -P now"
  format             = "qcow2"
  vm_name            = "mysql-${var.release_tag}.qcow2"
  output_directory   = "images/"
  headless           = var.headless
  memory             = 1024
}

build {
  name = "build"
  sources = [
    "source.qemu.debian"
  ]

  provisioner "file" {
    source      = "config/prometheus-mysqld-exporter"
    destination = "/tmp/prometheus-mysqld-exporter"
  }

  provisioner "file" {
    source      = "mysqlchk"
    destination = "/tmp/"
  }

  provisioner "shell" {
    inline = [<<-EOT
      echo "Waiting for cloud-init to finish..."
      cloud-init status --wait
      STATUS=$(cloud-init status | cut -d':' -f2 )
      if [ "$STATUS" != " done" ]
      then
          echo "FAILED to run cloud-init successfully."
          cat /var/log/cloud-init.log
          exit 1
      fi
    EOT
    ]
  }

  provisioner "shell" {
    inline = [<<-EOT
      #!/usr/bin/env bash

      # install tools and monitoring agents
      echo 'debconf debconf/frontend select Noninteractive' | sudo debconf-set-selections
      sudo apt update
      sudo apt install -y --no-install-recommends gnupg2 prometheus-mysqld-exporter

      # install Percona
      wget https://repo.percona.com/apt/percona-release_latest.$(lsb_release -sc)_all.deb
      sudo dpkg -i percona-release_latest.$(lsb_release -sc)_all.deb
      sudo apt update
      sudo percona-release setup ps${replace(var.mysql_version, ".", "")}-lts
      sudo apt install -y percona-server-server
      sudo systemctl disable mysql.service

      # monitoring config
      sudo mysql -e "CREATE USER IF NOT EXISTS 'prometheus'@'localhost' IDENTIFIED WITH auth_socket;"
      sudo mysql -e "GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO 'prometheus'@'localhost';"
      sudo mv -v /tmp/prometheus-mysqld-exporter /etc/default/ && sudo systemctl restart prometheus-mysqld-exporter

      sudo cp -v /tmp/mysqlchk/mysqlchk.sh /opt/mysqlchk.sh
      sudo cp -v /tmp/mysqlchk/mysqlchk@.service /etc/systemd/system
      sudo cp -v /tmp/mysqlchk/mysqlchk.socket /etc/systemd/system
      sudo systemctl enable --no-reload mysqlchk.socket

      # Here you would setup your provisioning scripts to configure this host
      # as a MySQL replica and start the mysql service on first boot.
    EOT
    ]
  }

  provisioner "shell" {
    execute_command = "echo 'packer' | {{ .Vars }} sudo -S -E bash '{{ .Path }}'"
    scripts         = ["scripts/cleanup.sh"]
  }

}
