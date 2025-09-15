require 'spec_helper'

describe 'iop::service_vmaas' do
  on_supported_os.each do |os, facts|
    context "on #{os}" do
      let(:facts) { facts }

      context 'with default parameters' do
        it { should compile.with_all_deps }

        # VMAAS service tests
        it { should contain_podman__quadlet('iop-service-vmaas-reposcan') }
        it { should contain_podman__quadlet('iop-service-vmaas-webapp-go') }
        it { should contain_class('iop::cvemap_downloader') }
      end

      context 'with ensure => absent' do
        let(:params) { { ensure: 'absent' } }

        it { should compile.with_all_deps }
        it { should contain_podman__quadlet('iop-service-vmaas-reposcan').with_ensure('absent') }
        it { should contain_podman__quadlet('iop-service-vmaas-webapp-go').with_ensure('absent') }
      end

      context 'with custom database parameters' do
        let(:params) do
          {
            database_user: 'test_user',
            database_name: 'test_db',
            database_password: 'test_password',
          }
        end

        it { should compile.with_all_deps }
        it { should contain_podman__quadlet('iop-service-vmaas-reposcan') }
        it { should contain_podman__quadlet('iop-service-vmaas-webapp-go') }
      end

      context 'secret subscription behavior' do
        it 'should ensure reposcan quadlet subscribes to all secrets' do
          should contain_podman__quadlet('iop-service-vmaas-reposcan').with(
            'subscribe' => [
              'Podman::Secret[iop-service-vmaas-reposcan-client-ca-cert]',
              'Podman::Secret[iop-service-vmaas-reposcan-database-username]',
              'Podman::Secret[iop-service-vmaas-reposcan-database-password]',
              'Podman::Secret[iop-service-vmaas-reposcan-database-name]',
              'Podman::Secret[iop-service-vmaas-reposcan-database-host]',
              'Podman::Secret[iop-service-vmaas-reposcan-database-port]'
            ]
          )
        end

        it 'should ensure webapp-go quadlet subscribes to database secrets' do
          should contain_podman__quadlet('iop-service-vmaas-webapp-go').with(
            'subscribe' => [
              'Podman::Secret[iop-service-vmaas-reposcan-database-username]',
              'Podman::Secret[iop-service-vmaas-reposcan-database-password]',
              'Podman::Secret[iop-service-vmaas-reposcan-database-name]',
              'Podman::Secret[iop-service-vmaas-reposcan-database-host]',
              'Podman::Secret[iop-service-vmaas-reposcan-database-port]'
            ]
          )
        end

        it 'should create secrets that services depend on' do
          should contain_podman__secret('iop-service-vmaas-reposcan-database-password')
          should contain_podman__secret('iop-service-vmaas-reposcan-database-username')
          should contain_podman__secret('iop-service-vmaas-reposcan-client-ca-cert')
        end

        it 'should ensure quadlets properly subscribe to secrets' do
          should contain_podman__quadlet('iop-service-vmaas-reposcan')
            .that_subscribes_to('Podman::Secret[iop-service-vmaas-reposcan-database-password]')
          should contain_podman__quadlet('iop-service-vmaas-webapp-go')
            .that_subscribes_to('Podman::Secret[iop-service-vmaas-reposcan-database-password]')
          should contain_podman__quadlet('iop-service-vmaas-reposcan')
            .that_subscribes_to('Podman::Secret[iop-service-vmaas-reposcan-client-ca-cert]')
        end
      end
    end
  end
end
