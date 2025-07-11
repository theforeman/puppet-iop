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
        class { 'iop::service_remediations': }
        PUPPET
      end
    end

    describe service('iop-service-remediations-api') do
      it { is_expected.to be_running }
      it { is_expected.to be_enabled }
    end

    describe command("podman run --network=iop-core-network quay.io/iop/remediations:latest curl -s -o /dev/null -w '%{http_code}' http://iop-service-remediations-api:9002/health") do
      its(:stdout) { should match /200/ }
    end
  end
end
