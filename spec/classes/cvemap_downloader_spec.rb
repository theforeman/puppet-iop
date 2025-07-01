require 'spec_helper'

describe 'iop::cvemap_downloader' do
  on_supported_os.each do |os, facts|
    context "on #{os}" do
      let(:facts) { facts }

      context 'with default parameters' do
        it { should compile.with_all_deps }
        it { should contain_file('/usr/local/bin/iop-cvemap-download.sh') }
        it { should contain_systemd__manage_unit('iop-cvemap-download.service') }
        it { should contain_systemd__timer('iop-cvemap-download.timer') }
        it { should contain_systemd__unit_file('iop-cvemap-download.path') }
      end

      context 'with ensure => absent' do
        let(:params) { { ensure: 'absent' } }
        
        it { should compile.with_all_deps }
        it { should contain_file('/usr/local/bin/iop-cvemap-download.sh').with_ensure('absent') }
        it { should contain_systemd__manage_unit('iop-cvemap-download.service').with_ensure('absent') }
        it { should contain_systemd__timer('iop-cvemap-download.timer').with_ensure('absent') }
        it { should contain_systemd__unit_file('iop-cvemap-download.path').with_ensure('absent') }
      end

      context 'with custom base_url' do
        let(:params) { { base_url: 'https://example.com/test.xml' } }
        
        it { should compile.with_all_deps }
        it { should contain_systemd__manage_unit('iop-cvemap-download.service') }
      end

      context 'with custom timer_interval' do
        let(:params) { { timer_interval: '12h' } }
        
        it { should compile.with_all_deps }
        it { should contain_systemd__timer('iop-cvemap-download.timer') }
      end
    end
  end
end
