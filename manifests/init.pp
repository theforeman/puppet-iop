# == Class: iop
#
# Install and configure IOP services
#
class iop (
) {
  include iop::core_engine
  include iop::core_ingress
  include iop::core_kafka
}
