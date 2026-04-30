require 'spec_helper_acceptance'

describe 'basic installation' do
  before(:all) do
    clean_test_environment
  end

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

  context 'with basic parameters' do
    it_behaves_like 'an idempotent resource'

    describe file("/var/lib/foreman/public/assets/apps/inventory/app.info.json") do
      it { is_expected.to be_file }
    end

    describe file("/var/lib/foreman/public/assets/apps/inventory") do
      it { is_expected.to be_directory }
      it { should be_mode 755 }
    end

    describe curl_command("http://#{host_inventory['fqdn']}/assets/apps/inventory/fed-mods.json") do
      its(:response_code) { should eq 200 }
    end
  end

  context 'with restrictive umask' do
    before(:context) do
      on default, 'echo "umask 0077" > /etc/profile.d/strict_umask.sh'
    end

    after(:context) do
      on default, 'rm -f /etc/profile.d/strict_umask.sh'
    end

    it_behaves_like 'an idempotent resource'

    describe file("/var/lib/foreman/public/assets/apps/inventory") do
      it { is_expected.to be_directory }
      it { should be_mode 755 }
    end

    describe curl_command("http://#{host_inventory['fqdn']}/assets/apps/inventory/fed-mods.json") do
      its(:response_code) { should eq 200 }
    end
  end

  context 'with ensure => absent' do
    it_behaves_like 'an idempotent resource' do
      let(:manifest) do
        <<-PUPPET
        class { 'iop::core_host_inventory_frontend':
          ensure => 'absent',
        }
        PUPPET
      end
    end

    describe file("/var/lib/foreman/public/assets/apps/inventory") do
      it { is_expected.not_to exist }
    end

    describe file("/var/lib/foreman/public/assets/apps/inventory/app.info.json") do
      it { is_expected.not_to exist }
    end
  end
end
