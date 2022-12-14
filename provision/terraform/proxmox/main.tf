terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "2.9.11"
    }
    sops = {
      source  = "carlpett/sops"
      version = "0.7.2"
    }
  }
}

data "sops_file" "proxmox_secrets" {
  source_file = "secret.sops.yaml"
}

provider "proxmox" {
  # url is the hostname (FQDN if you have one) for the proxmox host you'd like to connect to to issue the commands. my proxmox host is 'prox-1u'. Add /api2/json at the end for the API
  pm_api_url = data.sops_file.proxmox_secrets.data["pm_api_url"]

  # api token id is in the form of: <username>@pam!<tokenId>
  pm_api_token_id = data.sops_file.proxmox_secrets.data["pm_api_token_id"]

  # this is the full secret wrapped in quotes. don't worry, I've already deleted this from my proxmox cluster by the time you read this post
  pm_api_token_secret = data.sops_file.proxmox_secrets.data["pm_api_token_secret"]

  # leave tls_insecure set to true unless you have your proxmox SSL certificate situation fully sorted out (if you do, you will know)
  pm_tls_insecure = false
}

# resource is formatted to be "[type]" "[entity_name]" so in this case
# we are looking to create a proxmox_vm_qemu entity named test_server
resource "proxmox_vm_qemu" "k8s_master" {
  count = 1                           # just want 1 for now, set to 0 and apply to destroy VM
  name  = "master-${count.index + 1}" #count.index starts at 0, so + 1 means this VM will be named test-vm-1 in proxmox

  # this now reaches out to the vars file. I could've also used this var above in the pm_api_url setting but wanted to spell it out up there. target_node is different than api_url. target_node is which node hosts the template and thus also which node will host the new VM. it can be different than the host you use to communicate with the API. the variable contains the contents "prox-1u"
  target_node = "pve"

  # another variable with contents "ubuntu-2004-cloudinit-template"
  clone      = "fedora37-beta-cloudinit-template"
  full_clone = false

  # basic VM settings here. agent refers to guest agent
  agent    = 1
  os_type  = "cloud-init"
  cores    = 2
  sockets  = 1
  cpu      = "host"
  memory   = 14336
  scsihw   = "virtio-scsi-pci"
  bootdisk = "scsi0"

  disk {
    slot = 0
    # set disk size here. leave it small for testing because expanding the disk takes time.
    size     = "20G"
    type     = "scsi"
    storage  = "local-btrfs"
    iothread = 1
  }

  # if you want two NICs, just copy this whole network section and duplicate it
  network {
    model  = "virtio"
    bridge = "vmbr0"
  }

  # not sure exactly what this is for. presumably something about MAC addresses and ignore network changes during the life of the VM
  lifecycle {
    ignore_changes = [
      network,
    ]
  }

  # the ${count.index + 1} thing appends text to the end of the ip address
  # in this case, since we are only adding a single VM, the IP will
  # be 10.98.1.91 since count.index starts at 0. this is how you can create
  # multiple VMs and have an IP assigned to each (.91, .92, .93, etc.)

  ipconfig0  = "ip=10.1.5.5${count.index + 1}/24,gw=10.1.5.1"
  nameserver = "10.1.5.1"

  # sshkeys set using variables. the variable contains the text of the key.
  sshkeys = <<EOF
  ${data.sops_file.proxmox_secrets.data["ssh_key"]}
  EOF
}
# resource is formatted to be "[type]" "[entity_name]" so in this case
# we are looking to create a proxmox_vm_qemu entity named test_server
resource "proxmox_vm_qemu" "k8s_worker" {
  count = 2                           # just want 1 for now, set to 0 and apply to destroy VM
  name  = "worker-${count.index + 1}" #count.index starts at 0, so + 1 means this VM will be named test-vm-1 in proxmox

  # this now reaches out to the vars file. I could've also used this var above in the pm_api_url setting but wanted to spell it out up there. target_node is different than api_url. target_node is which node hosts the template and thus also which node will host the new VM. it can be different than the host you use to communicate with the API. the variable contains the contents "prox-1u"
  target_node = "pve"

  # another variable with contents "ubuntu-2004-cloudinit-template"
  clone      = "fedora37-beta-cloudinit-template"
  full_clone = false

  # basic VM settings here. agent refers to guest agent
  agent    = 1
  os_type  = "cloud-init"
  cores    = 2
  sockets  = 1
  cpu      = "host"
  memory   = 3072
  scsihw   = "virtio-scsi-pci"
  bootdisk = "scsi0"

  disk {
    slot = 0
    # set disk size here. leave it small for testing because expanding the disk takes time.
    size     = "50G"
    type     = "scsi"
    storage  = "local-btrfs"
    iothread = 1
  }

  # if you want two NICs, just copy this whole network section and duplicate it
  network {
    model  = "virtio"
    bridge = "vmbr0"
  }

  # not sure exactly what this is for. presumably something about MAC addresses and ignore network changes during the life of the VM
  lifecycle {
    ignore_changes = [
      network,
    ]
  }

  # the ${count.index + 1} thing appends text to the end of the ip address
  # in this case, since we are only adding a single VM, the IP will
  # be 10.98.1.91 since count.index starts at 0. this is how you can create
  # multiple VMs and have an IP assigned to each (.91, .92, .93, etc.)

  ipconfig0  = "ip=10.1.5.6${count.index + 1}/24,gw=10.1.5.1"
  nameserver = "10.1.5.1"

  # sshkeys set using variables. the variable contains the text of the key.
  sshkeys = <<EOF
  ${data.sops_file.proxmox_secrets.data["ssh_key"]}
  EOF
}
