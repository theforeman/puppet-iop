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
        include iop::core_kafka
        PUPPET
      end
    end

    describe service('iop-core-kafka') do
      it { is_expected.to be_running }
      it { is_expected.to be_enabled }
    end

    it 'should have iop-core-kafka-data volume' do
      result = shell('podman volume ls --format "{{.Name}}"')
      expect(result.stdout).to match(/iop-core-kafka-data/)
    end
  end
end
