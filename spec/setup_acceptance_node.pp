package { 'podman':
  ensure => installed,
}

class { 'foreman::repo':
  repo => 'nightly',
}
class { 'katello::repo':
  repo_version => 'nightly',
}
class { 'candlepin::repo':
  version => 'nightly',
}

file { '/etc/foreman-proxy':
  ensure => directory,
}

group { 'foreman-proxy':
  ensure => present,
}
