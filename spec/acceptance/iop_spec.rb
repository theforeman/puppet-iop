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
  end

  context 'with basic parameters' do
    it_behaves_like 'an idempotent resource' do
      let(:manifest) do
        <<-PUPPET
        file { '/var/lib/foreman':
          ensure => directory,
        }

        file { '/var/lib/foreman/assets':
          ensure => directory,
          require => File['/var/lib/foreman'],
        }

        file { '/var/lib/foreman/assets/apps':
          ensure => directory,
          require => File['/var/lib/foreman/assets'],
        }

        include foreman::config::apache

        class { 'iop': }
        PUPPET
      end
    end

    describe command('curl http://localhost:24443/') do
      its(:exit_status) { should eq 0 }
    end

    describe command('podman run --network=iop-core-network quay.io/iop/puptoo curl http://iop-core-puptoo:8000/metrics') do
      its(:exit_status) { should eq 0 }
    end

    describe command('podman run --network=iop-core-network quay.io/iop/yuptoo curl http://iop-core-yuptoo:5005/') do
      its(:exit_status) { should eq 0 }
    end

    describe command('podman run --network=iop-core-network quay.io/iop/ingress curl http://iop-core-ingress:8080/') do
      its(:exit_status) { should eq 0 }
    end

    describe command('curl http://localhost:24443/api/ingress') do
      its(:exit_status) { should eq 0 }
    end

    describe command('podman run --network=iop-core-network quay.io/iop/host-inventory:latest curl http://iop-core-host-inventory:9126/') do
      its(:exit_status) { should eq 0 }
    end

    describe service('iop-core-host-inventory-api') do
      it { is_expected.to be_running }
      it { is_expected.to be_enabled }
    end

    describe command('podman run --network=iop-core-network quay.io/iop/host-inventory curl http://iop-core-host-inventory-api:8081/health') do
      its(:exit_status) { should eq 0 }
    end
  end
end
