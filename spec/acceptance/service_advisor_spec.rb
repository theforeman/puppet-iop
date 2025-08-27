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
        class { 'iop::service_advisor': }
        PUPPET
      end
    end

    describe service('iop-service-advisor-backend-service') do
      it { is_expected.to be_running }
      it { is_expected.to be_enabled }
    end

    describe service('iop-service-advisor-backend-api') do
      it { is_expected.to be_running }
      it { is_expected.to be_enabled }
    end

    describe command("podman run --network=iop-core-network quay.io/iop/advisor-backend:latest curl -s -o /dev/null -w '%{http_code}' http://iop-service-advisor-backend-service:8000/api/insights/v1/status/live/") do
      its(:stdout) { should match /200/ }
    end

    describe 'FDW setup verification' do
      describe command('sudo -u postgres psql advisor_db -c "SELECT * FROM pg_foreign_server WHERE srvname = \'hbi_server\';"') do
        its(:stdout) { should match /hbi_server/ }
        its(:exit_status) { should eq 0 }
      end

      describe command('sudo -u postgres psql advisor_db -c "SELECT * FROM information_schema.user_mappings WHERE foreign_server_name = \'hbi_server\';"') do
        its(:stdout) { should match /advisor_user/ }
        its(:exit_status) { should eq 0 }
      end

      describe command('sudo -u postgres psql advisor_db -c "\\det inventory_source.*"') do
        its(:stdout) { should match /hosts/ }
        its(:exit_status) { should eq 0 }
      end

      describe command('sudo -u postgres psql advisor_db -c "\\dv inventory.*"') do
        its(:stdout) { should match /hosts/ }
        its(:exit_status) { should eq 0 }
      end

      describe command('sudo -u postgres psql advisor_db -c "SELECT 1 FROM inventory.hosts LIMIT 1;"') do
        its(:exit_status) { should eq 0 }
      end
    end
  end
end
