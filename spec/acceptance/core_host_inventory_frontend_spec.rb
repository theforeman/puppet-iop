require 'spec_helper_acceptance'

describe 'basic installation' do
  before(:all) do
    on default, 'systemctl stop iop-*'
    on default, 'rm -rf /etc/containers/systemd/*'
    on default, 'systemctl daemon-reload'
    on default, 'podman rm --all --force'
    on default, 'podman secret rm --all'
    on default, 'podman network rm iop-core-network --force'
    on default, 'dnf -y remove postgres*'
    on default, 'dnf -y remove foreman*'
  end

  context 'with basic parameters' do
    it_behaves_like 'an idempotent resource' do
      let(:manifest) do
        <<-PUPPET
        file { '/var/lib/foreman':
          ensure => directory,
        }

        file { '/var/lib/foreman/public':
          ensure => directory,
          require => File['/var/lib/foreman'],
        }

        file { '/var/lib/foreman/public/assets':
          ensure => directory,
          require => File['/var/lib/foreman/public'],
        }

        file { '/usr/share/foreman':
          ensure => directory,
        }

        file { '/usr/share/foreman/public':
          ensure => link,
          target => '/var/lib/foreman/public',
          require => [File['/usr/share/foreman'], File['/var/lib/foreman/public']],
        }

        include foreman::config::apache

        class { 'iop::core_host_inventory_frontend': }
        PUPPET
      end
    end

    describe file("/var/lib/foreman/public/assets/apps/inventory/app.info.json") do
      it { is_expected.to be_file }
    end

    describe file("/var/lib/foreman/public/assets/apps/inventory") do
      it { is_expected.to be_directory }
      it { should be_mode 755 }
    end
  end
end
