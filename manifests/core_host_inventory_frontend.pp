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
  ensure_resource('file', '/var/lib/foreman/public/assets/apps', { 'ensure' => 'directory' })

  iop_frontend { '/var/lib/foreman/public/assets/apps/inventory':
    ensure => $ensure,
    image  => $image,
  }
}
