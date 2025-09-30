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
        class { 'iop::service_remediations': }
        PUPPET
      end
    end

    describe service('iop-service-remediations-api') do
      it { is_expected.to be_running }
      it { is_expected.to be_enabled }
    end

    describe command("podman run --rm --network=iop-core-network quay.io/iop/remediations:latest curl -s -o /dev/null -w '%{http_code}' http://iop-service-remediations-api:9002/health") do
      its(:stdout) { should match /200/ }
    end
  end

  context 'with ensure => absent' do
    it_behaves_like 'an idempotent resource' do
      let(:manifest) do
        <<-PUPPET
        class { 'iop::service_remediations':
          ensure => 'absent',
        }
        PUPPET
      end
    end

    describe service('iop-service-remediations-api') do
      it { is_expected.not_to be_running }
      it { is_expected.not_to be_enabled }
    end

    describe file('/etc/containers/systemd/iop-service-remediations-api.container') do
      it { is_expected.not_to exist }
    end

    describe command('podman secret ls --format "{{.Name}}" | grep "^iop-service-remediations-"') do
      its(:exit_status) { should eq 1 }
      its(:stdout) { should be_empty }
    end
  end
end
