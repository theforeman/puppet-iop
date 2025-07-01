require 'spec_helper'

describe 'iop::metadata_downloader' do
  on_supported_os.each do |os, facts|
    context "on #{os}" do
      let(:facts) { facts }

      context 'with default parameters' do
        it { should compile.with_all_deps }
        it { should contain_file('/usr/local/bin/iop-metadata-download.sh') }
        it { should contain_systemd__timer_wrapper('iop-metadata-download-cvemap') }
        it { should contain_file('/usr/local/bin/iop-metadata-watcher.sh') }
        it { should contain_systemd__manage_unit('iop-metadata-download-cvemap-watcher.service') }
      end

      context 'with ensure => absent' do
        let(:params) { { ensure: 'absent' } }
        
        it { should compile.with_all_deps }
        it { should contain_file('/usr/local/bin/iop-metadata-download.sh').with_ensure('absent') }
        it { should contain_systemd__timer_wrapper('iop-metadata-download-cvemap').with_ensure('absent') }
        it { should contain_file('/usr/local/bin/iop-metadata-watcher.sh').with_ensure('absent') }
        it { should contain_systemd__manage_unit('iop-metadata-download-cvemap-watcher.service').with_ensure('absent') }
      end

      context 'with custom base_url' do
        let(:params) { { base_url: 'https://example.com/test.xml' } }
        
        it { should compile.with_all_deps }
        it { should contain_systemd__timer_wrapper('iop-metadata-download-cvemap').with_command("/usr/local/bin/iop-metadata-download.sh 'https://example.com/test.xml' '/var/www/html/pub/iop/data/meta/v1/cvemap.xml'") }
      end
    end
  end
end