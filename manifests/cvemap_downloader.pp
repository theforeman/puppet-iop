# == Class: iop::cvemap_downloader
#
# Download and manage CVE map XML files for vulnerability scanning
#
# === Parameters:
#
# $ensure:: Ensure service is present or absent
#
# $base_url:: Base URL for the CVE map file to download
#
# $timer_interval:: Interval between timer executions (default: 24h)
#
class iop::cvemap_downloader (
  Enum['present', 'absent'] $ensure = 'present',
  String $base_url = 'https://security.access.redhat.com/data/meta/v1/cvemap.xml',
  String $timer_interval = '24h',
) {
  include iop::core_gateway
  include iop::service_vmaas

  $script_path = '/usr/local/bin/iop-cvemap-download.sh'
  $basedir = '/var/www/html/pub'
  $relative_path = 'iop/data/meta/v1/cvemap.xml'
  $full_path = "${basedir}/${relative_path}"

  file { $script_path:
    ensure  => $ensure,
    content => file('iop/iop-cvemap-download.sh'),
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
  }

  systemd::manage_unit { 'iop-cvemap-download.service':
    ensure        => $ensure,
    unit_entry    => {
      'Description' => 'Manages cvemap.xml for IoP Vulnerability',
      'After'       => ['network-online.target', 'iop-core-gateway.service'],
      'Wants'       => ['network-online.target', 'iop-core-gateway.service'],
    },
    service_entry => {
      'Type'      => 'oneshot',
      'ExecStart' => "${script_path} '${base_url}' '${full_path}'",
      'User'      => 'root',
      'Group'     => 'root',
    },
    install_entry => {},
    enable        => false,
    active        => false,
    require       => [
      File[$script_path],
      Class['iop::core_gateway'],
    ],
  }

  $unit_enable = $ensure ? { 'present' => true, 'absent' => false }
  $unit_active = $ensure ? { 'present' => true, 'absent' => false }

  systemd::timer { 'iop-cvemap-download.timer':
    ensure        => $ensure,
    timer_content => epp('iop/iop-cvemap-download.timer.epp', { 'timer_interval' => $timer_interval }),
    active        => $unit_active,
    enable        => $unit_enable,
    require       => Systemd::Manage_unit['iop-cvemap-download.service'],
  }

  # Path unit that triggers the service when manual file changes
  systemd::unit_file { 'iop-cvemap-download.path':
    ensure  => $ensure,
    enable  => $unit_enable,
    active  => $unit_active,
    content => file('iop/iop-cvemap-download.path'),
    require => Systemd::Manage_unit['iop-cvemap-download.service'],
  }
}
