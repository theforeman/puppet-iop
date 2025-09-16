# == Class: iop
#
# Install and configure IOP services
#
# === Advanced parameters:
#
# $register_as_smartproxy:: Whether to register as a smart proxy
#
# $enable_vulnerability:: Enable vulnerability services
#
# $enable_advisor:: Enable advisor services
#
# $foreman_base_url:: Base URL for Foreman connection
#
# === Database parameters:
#
# $database_host:: Shared database host for all services
#
# $database_port:: Shared database port for all services
#
# $inventory_database_name:: Database name for host inventory service
#
# $inventory_database_user:: Database user for host inventory service
#
# $inventory_database_password:: Database password for host inventory service
#
# $vulnerability_database_name:: Database name for vulnerability service
#
# $vulnerability_database_user:: Database user for vulnerability service
#
# $vulnerability_database_password:: Database password for vulnerability service
#
# $vmaas_database_name:: Database name for vmaas service
#
# $vmaas_database_user:: Database user for vmaas service
#
# $vmaas_database_password:: Database password for vmaas service
#
# $advisor_database_name:: Database name for advisor service
#
# $advisor_database_user:: Database user for advisor service
#
# $advisor_database_password:: Database password for advisor service
#
# $remediations_database_name:: Database name for remediations service
#
# $remediations_database_user:: Database user for remediations service
#
# $remediations_database_password:: Database password for remediations service
#
class iop (
  Boolean $register_as_smartproxy = true,
  Boolean $enable_vulnerability = true,
  Boolean $enable_advisor = true,
  Optional[Stdlib::HTTPUrl] $foreman_base_url = undef,
  String[1] $database_host = '/var/run/postgresql/',
  Stdlib::Port $database_port = 5432,
  String[1] $inventory_database_name = 'inventory_db',
  String[1] $inventory_database_user = 'inventory_user',
  String[1] $inventory_database_password = $iop::params::inventory_database_password,
  String[1] $vulnerability_database_name = 'vulnerability_db',
  String[1] $vulnerability_database_user = 'vulnerability_admin',
  String[1] $vulnerability_database_password = $iop::params::vulnerability_database_password,
  String[1] $vmaas_database_name = 'vmaas_db',
  String[1] $vmaas_database_user = 'vmaas_admin',
  String[1] $vmaas_database_password = extlib::cache_data('iop_cache_data', 'vmaas_db_password', extlib::random_password(32)),
  String[1] $advisor_database_name = 'advisor_db',
  String[1] $advisor_database_user = 'advisor_user',
  String[1] $advisor_database_password = extlib::cache_data('iop_cache_data', 'advisor_db_password', extlib::random_password(32)),
  String[1] $remediations_database_name = 'remediations_db',
  String[1] $remediations_database_user = 'remediations_user',
  String[1] $remediations_database_password = extlib::cache_data('iop_cache_data', 'remediations_db_password', extlib::random_password(32)),
  Enum['disable', 'allow', 'prefer', 'require', 'verify-ca', 'verify-full'] $database_sslmode = 'disable',
  Optional[Stdlib::Absolutepath] $database_ssl_ca = undef,
) inherits iop::params {
  include iop::core_ingress
  include iop::core_puptoo
  include iop::core_yuptoo
  include iop::core_engine
  include iop::core_gateway
  class { 'iop::core_host_inventory':
    database_host     => $database_host,
    database_port     => $database_port,
    database_name     => $inventory_database_name,
    database_user     => $inventory_database_user,
    database_password => $inventory_database_password,
    database_sslmode  => $database_sslmode,
    database_ssl_ca   => $database_ssl_ca,
  }
  include iop::core_host_inventory_frontend

  if $enable_vulnerability {
    class { 'iop::service_vmaas':
      database_host     => $database_host,
      database_port     => $database_port,
      database_name     => $vmaas_database_name,
      database_user     => $vmaas_database_user,
      database_password => $vmaas_database_password,
      database_sslmode  => $database_sslmode,
      database_ssl_ca   => $database_ssl_ca,
    }
    include iop::service_vulnerability_frontend
    class { 'iop::service_vulnerability':
      database_host     => $database_host,
      database_port     => $database_port,
      database_name     => $vulnerability_database_name,
      database_user     => $vulnerability_database_user,
      database_password => $vulnerability_database_password,
      database_sslmode  => $database_sslmode,
      database_ssl_ca   => $database_ssl_ca,
    }
  }

  if $enable_advisor {
    include iop::service_advisor_frontend
    class { 'iop::service_advisor':
      database_host     => $database_host,
      database_port     => $database_port,
      database_name     => $advisor_database_name,
      database_user     => $advisor_database_user,
      database_password => $advisor_database_password,
      database_sslmode  => $database_sslmode,
      database_ssl_ca   => $database_ssl_ca,
    }
    class { 'iop::service_remediations':
      database_host     => $database_host,
      database_port     => $database_port,
      database_name     => $remediations_database_name,
      database_user     => $remediations_database_user,
      database_password => $remediations_database_password,
      database_sslmode  => $database_sslmode,
      database_ssl_ca   => $database_ssl_ca,
    }
  }

  if $register_as_smartproxy {
    $oauth_consumer_key = extlib::cache_data('foreman_cache_data', 'oauth_consumer_key', extlib::random_password(32))
    $oauth_consumer_secret = extlib::cache_data('foreman_cache_data', 'oauth_consumer_secret', extlib::random_password(32))

    $_foreman_base_url_real = pick($foreman_base_url, "https://${facts['networking']['fqdn']}")

    foreman_smartproxy { 'iop-gateway':
      ensure          => present,
      base_url        => $_foreman_base_url_real,
      consumer_key    => $oauth_consumer_key,
      consumer_secret => $oauth_consumer_secret,
      effective_user  => 'admin',
      ssl_ca          => $certs::iop::client_ca_cert,
      url             => 'https://localhost:24443',
      require         => [
        Class['iop::core_gateway'],
      ],
    }
  }

  class { 'iop_advisor_engine':
    ensure => 'absent',
  }
}
