require 'spec_helper_acceptance'

describe 'service restart on secret change' do
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

  context 'VMAAS service with initial configuration' do
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

    describe command('podman secret ls') do
      its(:stdout) { should match /iop-service-vmaas-reposcan-database-password/ }
      its(:stdout) { should match /iop-service-vmaas-reposcan-database-username/ }
      its(:stdout) { should match /iop-service-vmaas-reposcan-client-ca-cert/ }
      its(:exit_status) { should eq 0 }
    end
  end

  context 'VMAAS service secret rotation' do
    it_behaves_like 'an idempotent resource' do
      let(:manifest) do
        <<-PUPPET
        class { 'iop::service_vmaas':
          database_password => 'updated_vmaas_password'
        }
        PUPPET
      end
    end

    describe command('podman secret inspect iop-service-vmaas-reposcan-database-password --showsecret --format "{{.SecretData}}"') do
      its(:stdout) { should match /updated_vmaas_password/ }
      its(:exit_status) { should eq 0 }
    end

    describe service('iop-service-vmaas-reposcan') do
      it { is_expected.to be_running }
    end

    describe service('iop-service-vmaas-webapp-go') do
      it { is_expected.to be_running }
    end
  end
end
