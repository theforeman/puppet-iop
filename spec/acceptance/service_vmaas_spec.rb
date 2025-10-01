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
        class { 'iop::service_vmaas': }
        PUPPET
      end
    end

    describe service('iop-service-vmaas-reposcan') do
      it { is_expected.to be_running }
      it { is_expected.to be_enabled }
    end

    describe service('iop-service-vmaas-webapp-go') do
      it { is_expected.to be_running }
      it { is_expected.to be_enabled }
    end

    describe command("podman run --rm --network=iop-core-network quay.io/iop/vmaas curl -s -o /dev/null -w '%{http_code}' http://iop-service-vmaas-reposcan:8000/healthz") do
      its(:stdout) { should match /200/ }
    end

    describe service('iop-cvemap-download.timer') do
      it { is_expected.to be_enabled }
      it { is_expected.to be_running }
    end

    describe service('iop-cvemap-download.path') do
      it { is_expected.to be_enabled }
      it { is_expected.to be_running }
    end

    describe file('/usr/local/bin/iop-cvemap-download.sh') do
      it { is_expected.to be_file }
      it { is_expected.to be_executable }
    end
  end

  context 'with ensure => absent' do
    it_behaves_like 'an idempotent resource' do
      let(:manifest) do
        <<-PUPPET
        class { 'iop::service_vmaas':
          ensure => 'absent',
        }
        PUPPET
      end
    end

    describe service('iop-service-vmaas-reposcan') do
      it { is_expected.not_to be_running }
      it { is_expected.not_to be_enabled }
    end

    describe service('iop-service-vmaas-webapp-go') do
      it { is_expected.not_to be_running }
      it { is_expected.not_to be_enabled }
    end

    describe file('/etc/containers/systemd/iop-service-vmaas-reposcan.container') do
      it { is_expected.not_to exist }
    end

    describe file('/etc/containers/systemd/iop-service-vmaas-webapp-go.container') do
      it { is_expected.not_to exist }
    end

    describe command('podman secret ls --format "{{.Name}}" | grep "^iop-service-vmaas-"') do
      its(:exit_status) { should eq 1 }
      its(:stdout) { should be_empty }
    end

    describe command('podman volume ls --format "{{.Name}}" | grep "^iop-service-vmaas-"') do
      its(:exit_status) { should eq 1 }
      its(:stdout) { should be_empty }
    end

    describe service('iop-cvemap-download.timer') do
      it { is_expected.not_to be_running }
      it { is_expected.not_to be_enabled }
    end

    describe service('iop-cvemap-download.path') do
      it { is_expected.not_to be_running }
      it { is_expected.not_to be_enabled }
    end

    describe file('/usr/local/bin/iop-cvemap-download.sh') do
      it { is_expected.not_to exist }
    end

    describe file('/etc/systemd/system/iop-cvemap-download.service') do
      it { is_expected.not_to exist }
    end

    describe file('/etc/systemd/system/iop-cvemap-download.timer') do
      it { is_expected.not_to exist }
    end

    describe file('/etc/systemd/system/iop-cvemap-download.path') do
      it { is_expected.not_to exist }
    end
  end
end
