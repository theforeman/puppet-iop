# @summary Manages IoP metadata download
#
#
# @param ensure: 'present' to create and enable the service/timer,
#                'absent' to remove and disable them.
#                Defaults to 'present'.
#
# @param base_url: Base URL for the metadata
#
class iop::metadata_downloader (
  Enum['present', 'absent'] $ensure = 'present',
  String $base_url = 'https://security.access.redhat.com/data/'
) {

  # Define paths and names for the script, service, and timer
  $script_path = '/usr/local/bin/iop-metadata-download.sh'
  $service_name = 'iop-metadata-download-cvemap.service'
  $timer_name = 'iop-metadata-download-cvemap.timer'

  $basedir = '/var/www/html/pub/iop/data'
  $cvemap_base = 'meta/v1/cvemap.xml'
  $cvemap_path = "$basedir/$cvemap_base"

  file { dirname($cvemap_path):
    ensure  => directory,
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    recurse => true
  }


  file { $script_path:
    ensure  => $ensure,
    path    => $script_path,
    content => file('iop/iop-metadata-download.sh')
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
  }

  systemd::timer_wrapper {
    ensure                 => $ensure,
    command                => [$script_path, "${base_url}/$cvemap_base", $cvemap_path]
    on_boot_sec            => '1h',
    on_unit_active_sec     => '4h',
    service_unit_overrides => { 'Wants' => 'network-online.target' },
    timer_unit_overrides   => { 'Description' => 'Download cvemap.xml for IoP Vulnerability' },
  }
}
