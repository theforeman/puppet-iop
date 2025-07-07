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
        class { 'iop::core_engine': }
        PUPPET
      end
    end

    describe service('iop-core-engine') do
      it { is_expected.to be_running }
      it { is_expected.to be_enabled }
    end

    describe command('podman secret ls') do
      its(:stdout) { should match /iop-core-engine-config-yml/ }
      its(:exit_status) { should eq 0 }
    end
  end
end
