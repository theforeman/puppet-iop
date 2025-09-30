require 'spec_helper'

describe 'iop' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let :facts do
        os_facts
      end

      describe 'with default parameters' do
        it { should compile.with_all_deps }
        it { should contain_class('iop::core_network') }
        it { should contain_class('iop::core_kafka') }
        it { should contain_class('iop::core_ingress') }
        it { should contain_class('iop::core_puptoo') }
        it { should contain_class('iop::core_yuptoo') }
        it { should contain_class('iop::core_engine') }
        it { should contain_class('iop::core_gateway') }
        it { should contain_class('iop::core_host_inventory') }
        it { should contain_class('iop::core_host_inventory_frontend') }
        it { should contain_class('iop::service_vmaas') }
        it { should contain_class('iop::service_vulnerability_frontend') }
        it { should contain_class('iop::service_vulnerability') }
        it { should contain_class('iop::service_advisor_frontend') }
        it { should contain_class('iop::service_advisor') }
        it { should contain_class('iop::service_remediations') }
        it { should contain_foreman_smartproxy('iop-gateway') }
      end

      describe 'with ensure => absent' do
        let :params do
          {
            ensure: 'absent',
            register_as_smartproxy: false
          }
        end

        it { should compile.with_all_deps }
        it { should contain_class('iop::core_network').with_ensure('absent') }
        it { should contain_class('iop::core_kafka').with_ensure('absent') }
        it { should contain_class('iop::core_ingress').with_ensure('absent') }
        it { should contain_class('iop::core_puptoo').with_ensure('absent') }
        it { should contain_class('iop::core_yuptoo').with_ensure('absent') }
        it { should contain_class('iop::core_engine').with_ensure('absent') }
        it { should contain_class('iop::core_gateway').with_ensure('absent') }
        it { should contain_class('iop::core_host_inventory').with_ensure('absent') }
        it { should contain_class('iop::core_host_inventory_frontend').with_ensure('absent') }
        it { should contain_class('iop::service_vmaas').with_ensure('absent') }
        it { should contain_class('iop::service_vulnerability_frontend').with_ensure('absent') }
        it { should contain_class('iop::service_vulnerability').with_ensure('absent') }
        it { should contain_class('iop::service_advisor_frontend').with_ensure('absent') }
        it { should contain_class('iop::service_advisor').with_ensure('absent') }
        it { should contain_class('iop::service_remediations').with_ensure('absent') }
      end

      describe 'with register_as_smartproxy => false' do
        let :params do
          {
            register_as_smartproxy: false
          }
        end

        it { should compile.with_all_deps }
        it { should contain_class('iop::core_network') }
        it { should contain_class('iop::core_kafka') }
        it { should contain_class('iop::core_ingress') }
        it { should contain_class('iop::core_puptoo') }
        it { should contain_class('iop::core_yuptoo') }
        it { should contain_class('iop::core_engine') }
        it { should contain_class('iop::core_gateway') }
        it { should contain_class('iop::core_host_inventory') }
        it { should contain_class('iop::core_host_inventory_frontend') }
        it { should contain_class('iop::service_vmaas') }
        it { should contain_class('iop::service_vulnerability_frontend') }
        it { should contain_class('iop::service_vulnerability') }
        it { should contain_class('iop::service_advisor_frontend') }
        it { should contain_class('iop::service_advisor') }
        it { should contain_class('iop::service_remediations') }
        it { should_not contain_foreman_smartproxy('iop-gateway') }
      end
    end
  end
end
