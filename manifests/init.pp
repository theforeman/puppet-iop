# == Class: iop
#
# Install and configure IOP services
#
class iop (
) {
  include iop::core_kafka
  include iop::core_ingress
  include iop::core_puptoo
  include iop::core_yuptoo
  include iop::core_gateway
  include iop::core_host_inventory
}
