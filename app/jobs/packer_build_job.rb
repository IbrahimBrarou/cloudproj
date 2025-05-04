class PackerBuildJob < ApplicationJob
  queue_as :default

  def perform(vm_params)
    build_dir = Rails.root.join("tmp", "vms")
    Dir.mkdir(build_dir) unless Dir.exist?(build_dir)

    hcl_path = build_dir.join("template.pkr.hcl")
    File.write(hcl_path, generate_pkr_hcl(vm_params))

    Dir.chdir(build_dir) do
      system("packer init .")
      system("packer build .")
    end
  end

  private

  def generate_pkr_hcl(params)
    <<~HCL
      variable "iso_url" {
        type    = string
        default = "./ubuntu-22.04-autoinstall.iso"
      }
      
      variable "iso_checksum" {
        type    = string
        default = "sha256:e7c3a83f65e89284739c5b0595c0f3087faaad4794a97cf6ca4512c5d56e98b6"
      }
      
      variable "vm_name" {
        type    = string
        default = "ubuntu-2204-autoinstall-template"
      }
      
      packer {
        required_plugins {
          virtualbox = {
            version = ">= 1.0.0"
            source  = "github.com/hashicorp/virtualbox"
          }
        }
      }
      
      source "virtualbox-iso" "ubuntu_server" {
        guest_os_type = "Ubuntu_64"
        vm_name       = var.vm_name
        cpus          = #{params[:cpus] || 2}
        memory        = #{(params[:memory] || 4) * 2048}
        disk_size     = #{(params[:disk_size] || 20) * 20480}
        headless      = false
      
        iso_url        = var.iso_url
        iso_checksum   = var.iso_checksum
      
        boot_command   = ["<enter>"]
        boot_wait      = "10s"
      
        ssh_username   = "ubuntu"
        ssh_password   = "ubuntu"
        ssh_timeout    = "60m"
        ssh_handshake_attempts = 200
      
        output_directory = "output-${var.vm_name}"
      
        shutdown_command = "echo 'ubuntu' | sudo -S shutdown -P now"
        shutdown_timeout = "5m"
      }
      
      build {
        name    = "ubuntu-autoinstall-virtualbox"
        sources = ["source.virtualbox-iso.ubuntu_server"]
      
        provisioner "shell" {
          inline = [
            "echo 'Running provisioner scripts...'",
            "sleep 30",
            "echo 'ubuntu' | sudo -S apt-get update",
            "echo 'ubuntu' | sudo -S apt-get upgrade -y",
            #{(params[:packages] || []).map { |pkg| "\"echo 'ubuntu' | sudo -S apt-get install -y #{pkg}\"" }.join(",\n          ")},
            "echo 'Provisioning complete.'"
          ]
        }
      }
    HCL
  end
end
