require 'spec_helper'

describe 'iop::service_advisor_frontend' do
  on_supported_os.each do |os, facts|
    context "on #{os}" do
      let(:facts) { facts }

      context 'with default parameters' do
        it { should compile.with_all_deps }
        it { should contain_class('podman') }
        it { should contain_file('/var/lib/foreman/public/assets/apps').with_ensure('directory').with_mode('0755') }
        it { should contain_podman__image('service_advisor_frontend').with_image('quay.io/iop/advisor-frontend:foreman-3.18') }
        it { should contain_podman__image('service_advisor_frontend').with_ensure('present') }
        it { should contain_podman__image('service_advisor_frontend').with_exec_env(['REGISTRY_AUTH_FILE=/etc/foreman/registry-auth.json']) }
        it { should contain_iop_frontend('/var/lib/foreman/public/assets/apps/advisor').with_ensure('present') }
        it { should contain_iop_frontend('/var/lib/foreman/public/assets/apps/advisor').with_image('quay.io/iop/advisor-frontend:foreman-3.18') }
      end

      context 'with ensure => absent' do
        let(:params) { { ensure: 'absent' } }

        it { should compile.with_all_deps }
        it { should contain_podman__image('service_advisor_frontend').with_ensure('absent') }
        it { should contain_iop_frontend('/var/lib/foreman/public/assets/apps/advisor').with_ensure('absent') }
      end

      context 'with custom image' do
        let(:params) { { image: 'quay.io/custom/advisor-frontend:latest' } }

        it { should compile.with_all_deps }
        it { should contain_podman__image('service_advisor_frontend').with_image('quay.io/custom/advisor-frontend:latest') }
        it { should contain_iop_frontend('/var/lib/foreman/public/assets/apps/advisor').with_image('quay.io/custom/advisor-frontend:latest') }
      end
    end
  end
end
