# == Class: iop::database
#
# Configure database
#
# === Parameters:
#
class iop::database (
) {
  include postgresql::server

  postgresql::server::pg_hba_rule { 'allow iop network to access postgres':
    description => 'Open up PostgreSQL for access from socket via md5/scram-256',
    type        => 'local',
    database    => 'all',
    user        => 'all',
    auth_method => 'md5',
    order       => 2,
  }
}
