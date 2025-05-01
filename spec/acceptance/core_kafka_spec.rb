require 'spec_helper_acceptance'

describe 'iop::core_kafka' do
  context 'with basic parameters' do
    it_behaves_like 'an idempotent resource' do
      let(:manifest) do
        <<-PUPPET
        include iop::core_kafka
        PUPPET
      end
    end

    describe service('iop-core-kafka') do
      it { is_expected.to be_enabled }
      it { is_expected.to be_running }
    end
  end
end
