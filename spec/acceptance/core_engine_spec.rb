require 'spec_helper_acceptance'

describe 'basic installation' do
  before(:all) do
    clean_test_environment
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

  context 'with ensure => absent' do
    it_behaves_like 'an idempotent resource' do
      let(:manifest) do
        <<-PUPPET
        class { 'iop::core_engine':
          ensure => 'absent',
        }
        PUPPET
      end
    end

    describe service('iop-core-engine') do
      it { is_expected.not_to be_running }
      it { is_expected.not_to be_enabled }
    end

    describe file('/etc/containers/systemd/iop-core-engine.container') do
      it { is_expected.not_to exist }
    end

    describe command('podman secret ls --format "{{.Name}}" | grep "^iop-core-engine-"') do
      its(:exit_status) { should eq 1 }
      its(:stdout) { should be_empty }
    end
  end
end
