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
        class { 'iop::core_host_inventory': }
        PUPPET
      end
    end

    describe service('iop-core-host-inventory') do
      it { is_expected.to be_running }
      it { is_expected.to be_enabled }
    end

    describe service('iop-core-host-inventory-api') do
      it { is_expected.to be_running }
      it { is_expected.to be_enabled }
    end

    describe command("podman run --network=iop-core-network quay.io/iop/host-inventory curl -s -o /dev/null -w '%{http_code}' http://iop-core-host-inventory-api:8081/health") do
      its(:stdout) { should match /200/ }
    end

    describe service('iop-core-host-inventory-cleanup') do
      it { is_expected.not_to be_running }
    end

    describe command('systemctl is-enabled iop-core-host-inventory-cleanup') do
      its(:stdout) { should match /generated/ }
    end

    describe service('iop-core-host-inventory-cleanup.timer') do
      it { is_expected.to be_enabled }
      it { is_expected.to be_running }
    end

    describe file('/etc/systemd/system/iop-core-host-inventory-cleanup.timer') do
      it { is_expected.to be_file }
      its(:content) { should match /OnBootSec=10min/ }
      its(:content) { should match /OnUnitActiveSec=24h/ }
      its(:content) { should match /Persistent=true/ }
      its(:content) { should match /RandomizedDelaySec=300/ }
      its(:content) { should match /WantedBy=timers.target/ }
    end
  end

  context 'with ensure => absent' do
    it_behaves_like 'an idempotent resource' do
      let(:manifest) do
        <<-PUPPET
        class { 'iop::core_host_inventory':
          ensure => 'absent',
        }
        PUPPET
      end
    end

    describe service('iop-core-host-inventory') do
      it { is_expected.not_to be_running }
      it { is_expected.not_to be_enabled }
    end

    describe service('iop-core-host-inventory-api') do
      it { is_expected.not_to be_running }
      it { is_expected.not_to be_enabled }
    end

    describe service('iop-core-host-inventory-cleanup') do
      it { is_expected.not_to be_running }
      it { is_expected.not_to be_enabled }
    end

    describe service('iop-core-host-inventory-cleanup.timer') do
      it { is_expected.not_to be_running }
      it { is_expected.not_to be_enabled }
    end

    describe file('/etc/containers/systemd/iop-core-host-inventory.container') do
      it { is_expected.not_to exist }
    end

    describe file('/etc/containers/systemd/iop-core-host-inventory-api.container') do
      it { is_expected.not_to exist }
    end

    describe file('/etc/containers/systemd/iop-core-host-inventory-cleanup.container') do
      it { is_expected.not_to exist }
    end

    describe file('/etc/systemd/system/iop-core-host-inventory-cleanup.timer') do
      it { is_expected.not_to exist }
    end

    describe command('podman secret ls --format "{{.Name}}" | grep "^iop-core-host-inventory-"') do
      its(:exit_status) { should eq 1 }
      its(:stdout) { should be_empty }
    end
  end
end
