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
        class { 'iop::core_host_inventory': }
        PUPPET
      end
    end

    describe service('iop-core-host-inventory-migrate') do
      it { is_expected.to be_enabled }
    end

    describe service('iop-core-host-inventory-create-view') do
      it { is_expected.to be_enabled }
    end

    describe service('iop-core-host-inventory') do
      it { is_expected.to be_running }
      it { is_expected.to be_enabled }
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
