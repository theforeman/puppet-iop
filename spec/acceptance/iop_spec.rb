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
    on default, 'rm -rf /root/ssl-build'
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

    describe command("curl -s -o /dev/null -w '%{http_code}' https://localhost:24443/ --cert /root/ssl-build/localhost/localhost-iop-core-gateway-client.crt --key /root/ssl-build/localhost/localhost-iop-core-gateway-client.key --cacert /root/ssl-build/katello-server-ca.crt") do
      its(:stdout) { should match /200/ }
    end
  end

  context 'when registering as a smartproxy' do
    before(:context) do
      # Ensure foreman-installer-katello is installer prior
      # katello would pull it in, but it purges the candlepin caches
      # config/katello.migrations/231003142402-reset-store-credentials.rb
      on hosts, <<~SKIP_INSTALLER_MIGRATION
      applied=/etc/foreman-installer/scenarios.d/katello-migrations-applied
      migration=231003142402-reset-store-credentials.rb
      if ! grep -q $migration $applied 2> /dev/null ; then
        mkdir -p $(dirname $applied)
        echo "- $migration" >> $applied
      fi
      SKIP_INSTALLER_MIGRATION
    end

    it_behaves_like 'an idempotent resource' do
      let(:manifest) do
        <<-PUPPET
        include katello

        package { 'rubygem-foreman_rh_cloud':
          ensure => present,
        }

        Package['rubygem-foreman_rh_cloud'] -> Class['foreman::database']
        Package['rubygem-foreman_rh_cloud'] ~> Class['foreman::service']

        class { 'iop':
          register_as_smartproxy => true,
        }
        PUPPET
      end
    end

    describe service('iop-core-gateway') do
      it { is_expected.to be_running }
      it { is_expected.to be_enabled }
    end

    describe command("curl -s -o /dev/null -w '%{http_code}' https://localhost:24443/ --cert /root/ssl-build/localhost/localhost-iop-core-gateway-client.crt --key /root/ssl-build/localhost/localhost-iop-core-gateway-client.key --cacert /root/ssl-build/katello-server-ca.crt") do
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

    describe service('iop-service-vuln-manager') do
      it { is_expected.to be_running }
      it { is_expected.to be_enabled }
    end

    describe service('iop-service-vmaas-reposcan') do
      it { is_expected.to be_running }
      it { is_expected.to be_enabled }
    end

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
