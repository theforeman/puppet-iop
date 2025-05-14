# == Class: iop_advisor_engine
#
# Install and configure IOP services
#
class iop (
) {
  include iop::core_engine
  include iop::core_ingress
}
