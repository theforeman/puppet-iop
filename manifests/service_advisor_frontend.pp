# == Class: iop::service_advisor_frontend
#
# Install and configure the Advisor frontend assets
#
# === Parameters:
#
# $image::  The container image
#
# $ensure:: Ensure frontend assets are present or absent
#
class iop::service_advisor_frontend (
  String[1] $image = 'quay.io/iop/advisor-frontend:latest',
  Enum['present', 'absent'] $ensure = 'present',
) {
  ensure_resource('file', '/var/lib/foreman/public/assets/apps', { 'ensure' => 'directory' })

  iop_frontend { '/var/lib/foreman/public/assets/apps/advisor':
    ensure => $ensure,
    image  => $image,
  }
}
