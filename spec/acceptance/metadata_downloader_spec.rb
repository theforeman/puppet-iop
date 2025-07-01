require 'spec_helper_acceptance'

describe 'iop::metadata_downloader' do
  before(:all) do
    on default, 'systemctl stop iop-metadata-download-cvemap.timer || true'
    on default, 'systemctl disable iop-metadata-download-cvemap.timer || true'
    on default, 'systemctl stop iop-metadata-download-cvemap-watcher.service || true'
    on default, 'systemctl disable iop-metadata-download-cvemap-watcher.service || true'
    on default, 'rm -f /etc/systemd/system/iop-metadata-download-cvemap*'
    on default, 'rm -rf /var/www/html/pub/iop'
    on default, 'rm -f /usr/local/bin/iop-metadata-download.sh'
    on default, 'rm -f /usr/local/bin/iop-metadata-watcher.sh'
    on default, 'rm -f /var/lib/foreman/cvemap.xml'
    on default, 'systemctl daemon-reload'
    on default, 'mkdir -p /var/www/html/pub'
    on default, 'mkdir -p /var/lib/foreman'
  end

  context 'with default parameters' do
    it_behaves_like 'an idempotent resource' do
      let(:manifest) do
        <<-PUPPET
        class { 'iop::metadata_downloader': }
        PUPPET
      end
    end

    describe file('/usr/local/bin/iop-metadata-download.sh') do
      it { is_expected.to be_file }
      it { is_expected.to be_executable }
      its(:content) { is_expected.to match %r{#!/bin/bash} }
      its(:content) { is_expected.to match %r{set -euo pipefail} }
      its(:content) { is_expected.to match %r{If-None-Match} }
      its(:content) { is_expected.to match %r{mv "\$TEMP_FILE" "\$OUTPUT_FILE"} }
      its(:content) { is_expected.to match %r{/var/lib/foreman/cvemap.xml} }
      its(:content) { is_expected.to match %r{sha256sum} }
    end

    describe file('/etc/systemd/system/iop-metadata-download-cvemap.service') do
      it { is_expected.to be_file }
      its(:content) { is_expected.to match %r{/usr/local/bin/iop-metadata-download.sh} }
      its(:content) { is_expected.to match %r{https://security.access.redhat.com/data/meta/v1/cvemap.xml} }
      its(:content) { is_expected.to match %r{/var/www/html/pub/iop/data/meta/v1/cvemap.xml} }
      its(:content) { is_expected.to match %r{Wants=network-online.target} }
    end

    describe file('/etc/systemd/system/iop-metadata-download-cvemap.timer') do
      it { is_expected.to be_file }
      its(:content) { is_expected.to match %r{OnBootSec=1h} }
      its(:content) { is_expected.to match %r{OnUnitActiveSec=4h} }
      its(:content) { is_expected.to match %r{Description=Download cvemap.xml for IoP Vulnerability} }
      its(:content) { is_expected.to match %r{WantedBy=timers.target} }
    end

    describe service('iop-metadata-download-cvemap.timer') do
      it { is_expected.to be_enabled }
      it { is_expected.to be_running }
    end

    describe file('/usr/local/bin/iop-metadata-watcher.sh') do
      it { is_expected.to be_file }
      it { is_expected.to be_executable }
      its(:content) { is_expected.to match %r{polling mode} }
      its(:content) { is_expected.to match %r{/var/lib/foreman/cvemap.xml} }
      its(:content) { is_expected.to match %r{stat -c %Y} }
    end

    describe file('/etc/systemd/system/iop-metadata-download-cvemap-watcher.service') do
      it { is_expected.to be_file }
      its(:content) { is_expected.to match %r{Type=simple} }
      its(:content) { is_expected.to match %r{Restart=always} }
      its(:content) { is_expected.to match %r{RestartSec=10} }
      its(:content) { is_expected.to match %r{/usr/local/bin/iop-metadata-watcher.sh} }
    end

    describe service('iop-metadata-download-cvemap-watcher.service') do
      it { is_expected.to be_enabled }
      it { is_expected.to be_running }
    end

    context 'manual timer execution' do
      before(:all) do
        on default, 'systemctl start iop-metadata-download-cvemap.service'
        on default, 'sleep 10'
      end

      describe command('systemctl status iop-metadata-download-cvemap.service') do
        its(:stdout) { is_expected.to match %r{Active: inactive} }
      end

      describe file('/var/www/html/pub/iop/data/meta/v1/cvemap.xml') do
        it { is_expected.to be_file }
        it { is_expected.to be_owned_by 'root' }
        it { is_expected.to be_grouped_into 'root' }
        its(:size) { should be > 1000 }
      end

      describe file('/var/www/html/pub/iop/data/meta/v1/cvemap.xml.etag') do
        it { is_expected.to be_file }
        its(:size) { should be > 0 }
      end

      describe command('head -5 /var/www/html/pub/iop/data/meta/v1/cvemap.xml') do
        its(:stdout) { is_expected.to match %r{<?xml} }
        its(:exit_status) { should eq 0 }
      end

      describe command('ls /tmp/iop-metadata-download.* 2>/dev/null || echo "no temp files"') do
        its(:stdout) { is_expected.to match %r{no temp files} }
        its(:exit_status) { should eq 0 }
      end

      describe file('/var/www/html/pub/iop/data/meta/v1') do
        it { is_expected.to be_directory }
        it { is_expected.to be_owned_by 'root' }
        it { is_expected.to be_grouped_into 'root' }
      end

      context 'conditional download behavior' do
        before(:all) do
          on default, 'systemctl start iop-metadata-download-cvemap.service'
          on default, 'sleep 5'
        end

        describe command('journalctl -u iop-metadata-download-cvemap.service --since "1 minute ago"') do
          its(:exit_status) { should eq 0 }
          its(:stdout) { is_expected.to match %r{File not modified|Downloaded new version|Online mode} }
        end

        describe command('stat -c "%Y" /var/www/html/pub/iop/data/meta/v1/cvemap.xml') do
          its(:exit_status) { should eq 0 }
        end
      end
    end

    describe command('systemctl list-timers iop-metadata-download-cvemap.timer') do
      its(:stdout) { is_expected.to match %r{iop-metadata-download-cvemap.timer} }
      its(:exit_status) { should eq 0 }
    end

    describe command('systemctl show iop-metadata-download-cvemap.timer -p NextElapseUSecRealtime') do
      its(:stdout) { is_expected.to match %r{NextElapseUSecRealtime=} }
      its(:exit_status) { should eq 0 }
    end
  end

  context 'with custom base_url' do
    let(:custom_url) { 'https://example.com/test/file.xml' }

    it_behaves_like 'an idempotent resource' do
      let(:manifest) do
        <<-PUPPET
        class { 'iop::metadata_downloader':
          base_url => '#{custom_url}',
        }
        PUPPET
      end
    end

    describe file('/etc/systemd/system/iop-metadata-download-cvemap.service') do
      its(:content) { is_expected.to match %r{#{Regexp.escape(custom_url)}} }
      its(:content) { is_expected.to match %r{/var/www/html/pub/iop/data/meta/v1/cvemap.xml} }
    end
  end

  context 'offline mode with manual file' do
    let(:sample_xml) { '<?xml version="1.0"?><root><test>data</test></root>' }

    before(:all) do
      apply_manifest("class { 'iop::metadata_downloader': }", catch_failures: true)
      create_remote_file(default, '/var/lib/foreman/cvemap.xml', '<?xml version="1.0"?><root><test>manual data</test></root>')
    end

    after(:all) do
      on default, 'rm -f /var/lib/foreman/cvemap.xml'
      on default, 'rm -f /var/www/html/pub/iop/data/meta/v1/cvemap.xml*'
    end

    it 'uses manual file when present' do
      on default, 'systemctl start iop-metadata-download-cvemap.service'
      on default, 'sleep 5'
    end

    describe command('journalctl -u iop-metadata-download-cvemap.service --since "1 minute ago"') do
      its(:exit_status) { should eq 0 }
      its(:stdout) { is_expected.to match %r{Offline mode} }
      its(:stdout) { is_expected.to match %r{Copying updated manual file|Manual file unchanged} }
    end

    describe file('/var/www/html/pub/iop/data/meta/v1/cvemap.xml') do
      it { is_expected.to be_file }
      its(:content) { is_expected.to match %r{manual data} }
    end

    describe file('/var/www/html/pub/iop/data/meta/v1/cvemap.xml.checksum') do
      it { is_expected.to be_file }
      its(:size) { should be > 0 }
    end

    context 'manual file update detection' do
      before(:all) do
        on default, 'sleep 1'  # ensure different timestamp
        create_remote_file(default, '/var/lib/foreman/cvemap.xml', '<?xml version="1.0"?><root><test>updated manual data</test></root>')
        on default, 'systemctl start iop-metadata-download-cvemap.service'
        on default, 'sleep 5'
      end

      describe command('journalctl -u iop-metadata-download-cvemap.service --since "30 seconds ago"') do
        its(:stdout) { is_expected.to match %r{Copying updated manual file} }
      end

      describe file('/var/www/html/pub/iop/data/meta/v1/cvemap.xml') do
        its(:content) { is_expected.to match %r{updated manual data} }
      end
    end
  end

  context 'file watcher functionality' do
    before(:all) do
      apply_manifest("class { 'iop::metadata_downloader': }", catch_failures: true)
      on default, 'rm -f /var/www/html/pub/iop/data/meta/v1/cvemap.xml*'
      on default, 'rm -f /var/lib/foreman/cvemap.xml'
    end

    after(:all) do
      on default, 'rm -f /var/lib/foreman/cvemap.xml'
      on default, 'rm -f /var/www/html/pub/iop/data/meta/v1/cvemap.xml*'
    end

    it 'automatically copies file when manual file is created' do
      create_remote_file(default, '/var/lib/foreman/cvemap.xml', '<?xml version="1.0"?><root><test>watcher test data</test></root>')
      
      # Wait for file watcher service to detect change
      on default, 'sleep 15'
    end

    describe file('/var/www/html/pub/iop/data/meta/v1/cvemap.xml') do
      it { is_expected.to be_file }
      its(:content) { is_expected.to match %r{watcher test data} }
    end

    describe command('journalctl -u iop-metadata-download-cvemap-watcher.service --since "1 minute ago"') do
      its(:exit_status) { should eq 0 }
      its(:stdout) { is_expected.to match %r{Manual file copied successfully|File change detected|Copy script completed successfully|File creation detected via polling|File modification detected via polling} }
    end

    context 'manual service trigger test' do
      it 'verifies service works when triggered manually' do
        on default, 'sleep 3'  # ensure different timestamp
        create_remote_file(default, '/var/lib/foreman/cvemap.xml', '<?xml version="1.0"?><root><test>manual trigger data</test></root>')
        
        # Manually trigger the service to test if it works
        on default, 'systemctl start iop-metadata-download-cvemap-watcher.service'
        on default, 'sleep 5'
      end

      describe file('/var/www/html/pub/iop/data/meta/v1/cvemap.xml') do
        its(:content) { is_expected.to match %r{manual trigger data} }
      end

      describe command('journalctl -u iop-metadata-download-cvemap-watcher.service --since "30 seconds ago"') do
        its(:stdout) { is_expected.to match %r{Manual file copied successfully|File change detected|Copy script completed successfully|File creation detected via polling|File modification detected via polling} }
      end
    end

    context 'file modification triggers copy' do
      it 'detects file changes and copies updated content' do
        on default, 'sleep 3'  # ensure different timestamp
        
        # Check status before modification
        on default, 'systemctl status iop-metadata-download-cvemap-watcher.service || true'
        on default, 'systemctl is-active iop-metadata-download-cvemap-watcher.service || true'
        
        create_remote_file(default, '/var/lib/foreman/cvemap.xml', '<?xml version="1.0"?><root><test>updated watcher data</test></root>')
        
        # Wait for inotify/polling-based service to detect and process change
        on default, 'sleep 15'
        
        # Check what happened
        on default, 'systemctl status iop-metadata-download-cvemap-watcher.service || true'
        on default, 'journalctl -u iop-metadata-download-cvemap-watcher.service --since "1 minute ago" || true'
      end

      describe file('/var/www/html/pub/iop/data/meta/v1/cvemap.xml') do
        its(:content) { is_expected.to match %r{updated watcher data} }
      end

      describe command('journalctl -u iop-metadata-download-cvemap-watcher.service --since "30 seconds ago"') do
        its(:stdout) { is_expected.to match %r{Manual file copied successfully|File change detected|Copy script completed successfully|File creation detected via polling|File modification detected via polling} }
      end
    end

    context 'retry mechanism validation' do
      before(:all) do
        # Make output directory temporarily unwritable to test retry logic
        on default, 'chmod 555 /var/www/html/pub/iop/data/meta/v1'
        on default, 'sleep 1'
        create_remote_file(default, '/var/lib/foreman/cvemap.xml', '<?xml version="1.0"?><root><test>retry test data</test></root>')
        on default, 'sleep 5'
        # Restore write permissions
        on default, 'chmod 755 /var/www/html/pub/iop/data/meta/v1'
        on default, 'sleep 8'  # Allow for retry attempts
      end

      describe command('journalctl -u iop-metadata-download-cvemap-watcher.service --since "1 minute ago"') do
        its(:stdout) { is_expected.to match %r{Copy attempt.*failed|Manual file copied successfully} }
      end
    end
  end
end
