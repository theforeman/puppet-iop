require 'spec_helper_acceptance'

describe 'basic installation' do
  context 'with basic parameters' do
    it_behaves_like 'an idempotent resource' do
      let(:manifest) do
        <<-PUPPET
        include iop::core_host_inventory_web
        PUPPET
      end
    end

    describe service('iop-core-host-inventory-web') do
      it { is_expected.to be_running }
      it { is_expected.to be_enabled }
    end
  end
end
