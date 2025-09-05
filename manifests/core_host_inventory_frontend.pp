# == Class: iop::core_host_inventory_frontend
#
# Install and configure the Host Inventory frontend assets
#
# === Parameters:
#
# $image::  The container image
#
# $ensure:: Ensure frontend assets are present or absent
#
class iop::core_host_inventory_frontend (
  String[1] $image = 'quay.io/iop/host-inventory-frontend:latest',
  Enum['present', 'absent'] $ensure = 'present',
) {
  include podman
  ensure_resource('file', '/var/lib/foreman/public/assets/apps', { 'ensure' => 'directory' })

  podman::image { 'core_host_inventory_frontend':
    ensure   => $ensure,
    image    => $image,
    exec_env => ['REGISTRY_AUTH_FILE=/etc/foreman/registry-auth.json'],
  }

  iop_frontend { '/var/lib/foreman/public/assets/apps/inventory':
    ensure  => $ensure,
    image   => $image,
    require => Podman::Image['core_host_inventory_frontend'],
  }
}
