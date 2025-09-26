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
        class { 'iop::core_gateway': }
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
  end

  context 'with ensure => absent' do
    it_behaves_like 'an idempotent resource' do
      let(:manifest) do
        <<-PUPPET
        class { 'iop::core_gateway':
          ensure => 'absent',
        }
        PUPPET
      end
    end

    describe service('iop-core-gateway') do
      it { is_expected.not_to be_running }
      it { is_expected.not_to be_enabled }
    end

    describe file('/etc/containers/systemd/iop-core-gateway.container') do
      it { is_expected.not_to exist }
    end

    describe command('podman secret ls --format "{{.Name}}" | grep "^iop-core-gateway-"') do
      its(:exit_status) { should eq 1 }
      its(:stdout) { should be_empty }
    end
  end
end
