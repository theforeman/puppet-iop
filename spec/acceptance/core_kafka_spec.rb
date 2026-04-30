require 'spec_helper_acceptance'

describe 'basic installation' do
  before(:all) do
    clean_test_environment
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
  end

  context 'with ensure => absent' do
    it_behaves_like 'an idempotent resource' do
      let(:manifest) do
        <<-PUPPET
        class { 'iop::core_kafka':
          ensure => 'absent',
        }
        PUPPET
      end
    end

    describe service('iop-core-kafka') do
      it { is_expected.not_to be_running }
      it { is_expected.not_to be_enabled }
    end

    describe file('/etc/containers/systemd/iop-core-kafka.container') do
      it { is_expected.not_to exist }
    end

    describe command('podman volume ls --format "{{.Name}}" | grep "^iop-core-kafka-"') do
      its(:exit_status) { should eq 1 }
      its(:stdout) { should be_empty }
    end
  end
end
