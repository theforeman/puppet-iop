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

  shared_examples 'foreman directory setup' do
    let(:foreman_setup) do
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

      file { '/var/lib/foreman/public/assets/apps':
        ensure => directory,
        require => File['/var/lib/foreman/public/assets'],
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
      PUPPET
    end
  end

  context 'with default parameters (vulnerability and advisor enabled)' do
    include_examples 'foreman directory setup'

    it_behaves_like 'an idempotent resource' do
      let(:manifest) do
        <<-PUPPET
        #{foreman_setup}

        class { 'iop': }
        PUPPET
      end
    end

    # Core services should always be running
    describe service('iop-core-host-inventory-api') do
      it { is_expected.to be_running }
      it { is_expected.to be_enabled }
    end

    describe command("curl -s -o /dev/null -w '%{http_code}' https://localhost:24443/ --cert /root/ssl-build/#{host_inventory['fqdn']}/#{host_inventory['fqdn']}-foreman-proxy-client.crt --key /root/ssl-build/#{host_inventory['fqdn']}/#{host_inventory['fqdn']}-foreman-proxy-client.key --cacert /root/ssl-build/katello-server-ca.crt") do
      its(:stdout) { should match /200/ }
    end

    describe command("podman run --network=iop-core-network quay.io/iop/puptoo curl -s -o /dev/null -w '%{http_code}' http://iop-core-puptoo:8000/metrics") do
      its(:stdout) { should match /200/ }
    end

    describe command("podman run --network=iop-core-network quay.io/iop/yuptoo curl -s -o /dev/null -w '%{http_code}' http://iop-core-yuptoo:5005/") do
      its(:stdout) { should match /200/ }
    end

    describe command("podman run --network=iop-core-network quay.io/iop/ingress curl -s -o /dev/null -w '%{http_code}' http://iop-core-ingress:8080/") do
      its(:stdout) { should match /200/ }
    end

    describe command("podman run --network=iop-core-network quay.io/iop/host-inventory:latest curl -s -o /dev/null -w '%{http_code}' http://iop-core-host-inventory:9126/") do
      its(:stdout) { should match /200/ }
    end

    describe command("podman run --network=iop-core-network quay.io/iop/host-inventory curl -s -o /dev/null -w '%{http_code}' http://iop-core-host-inventory-api:8081/health") do
      its(:stdout) { should match /200/ }
    end

    # Vulnerability services should be running
    describe service('iop-service-vuln-manager') do
      it { is_expected.to be_running }
      it { is_expected.to be_enabled }
    end

    describe service('iop-service-vmaas-reposcan') do
      it { is_expected.to be_running }
      it { is_expected.to be_enabled }
    end

    # Advisor services should be running
    describe service('iop-service-advisor-backend-service') do
      it { is_expected.to be_running }
      it { is_expected.to be_enabled }
    end

    describe service('iop-service-advisor-backend-api') do
      it { is_expected.to be_running }
      it { is_expected.to be_enabled }
    end

    describe service('iop-service-remediations-api') do
      it { is_expected.to be_running }
      it { is_expected.to be_enabled }
    end
  end
end
