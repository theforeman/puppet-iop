require 'spec_helper'

describe 'iop::core_host_inventory' do
  on_supported_os.each do |os, facts|
    context "on #{os}" do
      let(:facts) { facts }

      context 'with default parameters' do
        it { should compile.with_all_deps }

        it { should contain_podman__quadlet('iop-core-host-inventory') }
        it { should contain_podman__quadlet('iop-core-host-inventory-api') }
        it { should contain_podman__quadlet('iop-core-host-inventory-migrate') }
        it { should contain_podman__quadlet('iop-core-host-inventory-cleanup') }

        it { should contain_postgresql_psql('create_or_replace_remote_view_inventory_hosts') }
      end
    end
  end
end
