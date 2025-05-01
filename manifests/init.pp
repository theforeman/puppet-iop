# == Class: iop_advisor_engine
#
# Install and configure IOP services
#
class iop_advisor_engine (
) {
  include iop::core_engine
  include iop::core_ingress
}
