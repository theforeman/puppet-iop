require 'spec_helper'

describe 'iop' do
  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let :facts do
        os_facts
      end

      describe 'with default parameters' do
        it { should compile.with_all_deps }
        it { should contain_class('iop::core_ingress') }
        it { should contain_class('iop::core_puptoo') }
        it { should contain_class('iop::core_yuptoo') }
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

      describe 'with enable_vulnerability => false' do
        let :params do
          {
            enable_vulnerability: false
          }
        end

        it { should compile.with_all_deps }
        it { should contain_class('iop::core_ingress') }
        it { should contain_class('iop::core_puptoo') }
        it { should contain_class('iop::core_yuptoo') }
        it { should contain_class('iop::core_gateway') }
        it { should contain_class('iop::core_host_inventory') }
        it { should contain_class('iop::core_host_inventory_frontend') }
        it { should_not contain_class('iop::service_vmaas') }
        it { should_not contain_class('iop::service_vulnerability_frontend') }
        it { should_not contain_class('iop::service_vulnerability') }
        it { should contain_class('iop::service_advisor_frontend') }
        it { should contain_class('iop::service_advisor') }
        it { should contain_class('iop::service_remediations') }
      end

      describe 'with enable_advisor => false' do
        let :params do
          {
            enable_advisor: false
          }
        end

        it { should compile.with_all_deps }
        it { should contain_class('iop::core_ingress') }
        it { should contain_class('iop::core_puptoo') }
        it { should contain_class('iop::core_yuptoo') }
        it { should contain_class('iop::core_gateway') }
        it { should contain_class('iop::core_host_inventory') }
        it { should contain_class('iop::core_host_inventory_frontend') }
        it { should contain_class('iop::service_vmaas') }
        it { should contain_class('iop::service_vulnerability_frontend') }
        it { should contain_class('iop::service_vulnerability') }
        it { should_not contain_class('iop::service_advisor_frontend') }
        it { should_not contain_class('iop::service_advisor') }
        it { should_not contain_class('iop::service_remediations') }
      end

      describe 'with both enable_vulnerability => false and enable_advisor => false' do
        let :params do
          {
            enable_vulnerability: false,
            enable_advisor: false
          }
        end

        it { should compile.with_all_deps }
        it { should contain_class('iop::core_ingress') }
        it { should contain_class('iop::core_puptoo') }
        it { should contain_class('iop::core_yuptoo') }
        it { should contain_class('iop::core_gateway') }
        it { should contain_class('iop::core_host_inventory') }
        it { should contain_class('iop::core_host_inventory_frontend') }
        it { should_not contain_class('iop::service_vmaas') }
        it { should_not contain_class('iop::service_vulnerability_frontend') }
        it { should_not contain_class('iop::service_vulnerability') }
        it { should_not contain_class('iop::service_advisor_frontend') }
        it { should_not contain_class('iop::service_advisor') }
        it { should_not contain_class('iop::service_remediations') }
      end
    end
  end
end
