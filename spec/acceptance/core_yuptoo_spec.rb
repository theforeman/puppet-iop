require 'spec_helper_acceptance'

describe 'basic installation' do
  before(:all) do
    clean_test_environment
  end

  context 'with basic parameters' do
    it_behaves_like 'an idempotent resource' do
      let(:manifest) do
        <<-PUPPET
        include iop::core_yuptoo
        PUPPET
      end
    end

    describe service('iop-core-yuptoo') do
      it { is_expected.to be_running }
      it { is_expected.to be_enabled }
    end

    describe command("podman run --rm --network=iop-core-network quay.io/iop/yuptoo curl -s -o /dev/null -w '%{http_code}' http://iop-core-yuptoo:5005/") do
      its(:stdout) { should match /200/ }
    end
  end

  context 'with ensure => absent' do
    it_behaves_like 'an idempotent resource' do
      let(:manifest) do
        <<-PUPPET
        class { 'iop::core_yuptoo':
          ensure => 'absent',
        }
        PUPPET
      end
    end

    describe service('iop-core-yuptoo') do
      it { is_expected.not_to be_running }
      it { is_expected.not_to be_enabled }
    end

    describe file('/etc/containers/systemd/iop-core-yuptoo.container') do
      it { is_expected.not_to exist }
    end
  end
end
