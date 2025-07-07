# == Class: iop
#
# Install and configure IOP services
#
# === Parameters:
#
# $enable_vulnerability:: Enable vulnerability services
#
# $enable_advisor:: Enable advisor services
#
class iop (
  Boolean $enable_vulnerability = true,
  Boolean $enable_advisor = true,
) {
  include iop::core_ingress
  include iop::core_puptoo
  include iop::core_yuptoo
  include iop::core_engine
  include iop::core_gateway
  include iop::core_host_inventory
  if $enable_vulnerability {
    include iop::service_vmaas
    include iop::service_vulnerability_frontend
    include iop::service_vulnerability
  }

  if $enable_advisor {
    include iop::service_advisor_frontend
    include iop::service_advisor
    include iop::service_remediations
  }
}
