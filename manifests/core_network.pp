# == Class: iop::core_network
#
# Configure podman network for services
#
# === Parameters:
#
# $ensure:: Ensure service is present or absent
#
class iop::core_network (
  Enum['present', 'absent'] $ensure = 'present',
) {
  include podman

  $subnet = '10.130.0.0/24'
  $gateway = '10.130.0.1'

  podman::network { 'iop-core-network':
    ensure  => $ensure,
    driver  => 'bridge',
    subnet  => $subnet,
    gateway => $gateway,
  }
}
