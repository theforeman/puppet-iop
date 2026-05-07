require 'spec_helper'

describe 'iop::core_host_inventory_frontend' do
  on_supported_os.each do |os, facts|
    context "on #{os}" do
      let(:facts) { facts }

      context 'with default parameters' do
        it { should compile.with_all_deps }
        it { should contain_class('podman') }
        it { should contain_file('/var/lib/foreman/public/assets/apps').with_ensure('directory').with_mode('0755') }
        it { should contain_podman__image('core_host_inventory_frontend').with_image('quay.io/iop/host-inventory-frontend:foreman-3.18') }
        it { should contain_podman__image('core_host_inventory_frontend').with_ensure('present') }
        it { should contain_podman__image('core_host_inventory_frontend').with_exec_env(['REGISTRY_AUTH_FILE=/etc/foreman/registry-auth.json']) }
        it { should contain_iop_frontend('/var/lib/foreman/public/assets/apps/inventory').with_ensure('present') }
        it { should contain_iop_frontend('/var/lib/foreman/public/assets/apps/inventory').with_image('quay.io/iop/host-inventory-frontend:foreman-3.18') }
      end

      context 'with ensure => absent' do
        let(:params) { { ensure: 'absent' } }

        it { should compile.with_all_deps }
        it { should contain_podman__image('core_host_inventory_frontend').with_ensure('absent') }
        it { should contain_iop_frontend('/var/lib/foreman/public/assets/apps/inventory').with_ensure('absent') }
      end

      context 'with custom image' do
        let(:params) { { image: 'quay.io/custom/host-inventory-frontend:latest' } }

        it { should compile.with_all_deps }
        it { should contain_podman__image('core_host_inventory_frontend').with_image('quay.io/custom/host-inventory-frontend:latest') }
        it { should contain_iop_frontend('/var/lib/foreman/public/assets/apps/inventory').with_image('quay.io/custom/host-inventory-frontend:latest') }
      end
    end
  end
end
