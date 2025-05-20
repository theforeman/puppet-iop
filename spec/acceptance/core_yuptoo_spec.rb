require 'spec_helper_acceptance'

describe 'basic installation' do
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

    describe command('podman run --network=iop-core-network quay.io/iop/yuptoo curl http://iop-core-yuptoo:5005/') do
      its(:exit_status) { should eq 0 }
    end
  end
end
