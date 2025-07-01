# @summary Manages IoP metadata download
#
# @param ensure
#   'present' to create and enable the service/timer,
#   'absent' to remove and disable them.
#   Defaults to 'present'.
#
# @param base_url
#   Base URL for the metadata file to download.
#   Defaults to the Red Hat security CVE map XML file.
#
class iop::metadata_downloader (
  Enum['present', 'absent'] $ensure = 'present',
  String $base_url = 'https://security.access.redhat.com/data/meta/v1/cvemap.xml',
) {
  $script_path = '/usr/local/bin/iop-metadata-download.sh'
  $basedir = '/var/www/html/pub'
  $relative_path = 'iop/data/meta/v1/cvemap.xml'
  $full_path = "${basedir}/${relative_path}"

  file { $script_path:
    ensure => $ensure,
    source => 'puppet:///modules/iop/iop-metadata-download.sh',
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  systemd::timer_wrapper { 'iop-metadata-download-cvemap':
    ensure                 => $ensure,
    command                => "${script_path} '${base_url}' '${full_path}'",
    on_boot_sec            => '1h',
    on_unit_active_sec     => '4h',
    service_unit_overrides => { 'Wants' => 'network-online.target' },
    timer_unit_overrides   => { 'Description' => 'Download cvemap.xml for IoP Vulnerability' },
    require                => File[$script_path],
  }

  # File watcher for manual cvemap.xml changes using inotify-based service
  $watcher_script_path = '/usr/local/bin/iop-metadata-watcher.sh'
  $watcher_enable = $ensure ? { 'present' => true, default => false }
  $watcher_active = $ensure ? { 'present' => true, default => false }

  file { $watcher_script_path:
    ensure => $ensure,
    source => 'puppet:///modules/iop/iop-metadata-watcher.sh',
    owner  => 'root',
    group  => 'root',
    mode   => '0755',
  }

  systemd::manage_unit { 'iop-metadata-download-cvemap-watcher.service':
    ensure        => $ensure,
    unit_entry    => {
      'Description' => 'Watch and copy manual cvemap.xml file when changed',
      'After'       => 'network-online.target',
    },
    service_entry => {
      'Type'       => 'simple',
      'ExecStart'  => "${watcher_script_path} ${base_url} ${full_path}",
      'Restart'    => 'always',
      'RestartSec' => '10',
      'User'       => 'root',
      'Group'      => 'root',
    },
    install_entry => {
      'WantedBy' => 'multi-user.target',
    },
    enable        => $watcher_enable,
    active        => $watcher_active,
    require       => [File[$script_path], File[$watcher_script_path]],
  }
}
