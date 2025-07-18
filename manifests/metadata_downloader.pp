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
  $basedir = '/var/www/html/pub'
  $path = dirname($base_url)
  $filename = 'cvemap.xml'
  $full_path = "${basedir}/${path}/${filename}"

  systemd::timer_wrapper { 'iop-metadata-download-cvemap':
    ensure                 => $ensure,
    command                => "/usr/bin/curl --create-dirs --fail --silent --remote-time --time-cond ${full_path} --output ${full_path} ${base_url}",
    on_boot_sec            => '1h',
    on_unit_active_sec     => '4h',
    service_unit_overrides => { 'Wants' => 'network-online.target' },
    timer_unit_overrides   => { 'Description' => 'Download cvemap.xml for IoP Vulnerability' },
  }
}
