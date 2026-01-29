require 'spec_helper'

# Helper to extract secret content whether wrapped in Sensitive or not
def get_secret_content(secret)
  value = secret[:secret]
  value.respond_to?(:unwrap) ? value.unwrap : value
end

describe 'iop::core_engine' do
  on_supported_os.each do |os, facts|
    context "on #{os}" do
      let(:facts) { facts }

      context 'with default parameters' do
        it { should compile.with_all_deps }
        it { should contain_podman__quadlet('iop-core-engine') }
        it { should contain_podman__secret('iop-core-engine-config-yml') }
      end

      context 'with ensure => absent' do
        let(:params) { { ensure: 'absent' } }

        it { should compile.with_all_deps }
        it { should contain_podman__quadlet('iop-core-engine').with_ensure('absent') }
        it { should contain_podman__secret('iop-core-engine-config-yml').with_ensure('absent') }
      end

      context 'with custom log levels' do
        let(:params) do
          {
            log_level_insights_core_dr: 'DEBUG',
            log_level_insights_messaging: 'WARNING',
            log_level_insights_kafka_service: 'ERROR',
            log_level_root: 'CRITICAL',
          }
        end

        it { should compile.with_all_deps }
        it { should contain_podman__quadlet('iop-core-engine') }
        it { should contain_podman__secret('iop-core-engine-config-yml') }

        it 'should configure custom log levels in the config secret' do
          secret = catalogue.resource('podman::secret', 'iop-core-engine-config-yml')
          content = get_secret_content(secret)
          expect(content).to include('insights.core.dr:')
          expect(content).to include('level: "DEBUG"')
          expect(content).to include('insights_messaging:')
          expect(content).to match(/insights_messaging:\s+level: "WARNING"/)
          expect(content).to match(/insights_kafka_service:\s+level: "ERROR"/)
          expect(content).to match(/"":\s+level: "CRITICAL"/)
        end
      end

      context 'with default log levels' do
        it 'should configure default log levels in the config secret' do
          secret = catalogue.resource('podman::secret', 'iop-core-engine-config-yml')
          content = get_secret_content(secret)
          expect(content).to match(/insights\.core\.dr:\s+level: "ERROR"/)
          expect(content).to match(/insights_messaging:\s+level: "INFO"/)
          expect(content).to match(/insights_kafka_service:\s+level: "INFO"/)
          expect(content).to match(/"":\s+level: "INFO"/)
        end
      end

      context 'with invalid log level' do
        let(:params) { { log_level_root: 'INVALID' } }

        it { should_not compile }
      end

      %w[DEBUG INFO WARNING ERROR CRITICAL].each do |level|
        context "with log_level_root => #{level}" do
          let(:params) { { log_level_root: level } }

          it { should compile.with_all_deps }

          it "should set root logger to #{level}" do
            secret = catalogue.resource('podman::secret', 'iop-core-engine-config-yml')
            content = get_secret_content(secret)
            expect(content).to match(/"":\s+level: "#{level}"/)
          end
        end
      end

      context 'secret subscription behavior' do
        it 'should ensure engine service subscribes to config secret' do
          should contain_podman__quadlet('iop-core-engine').with(
            'subscribe' => ['Podman::Secret[iop-core-engine-config-yml]']
          )
        end

        it 'should ensure engine service subscribes to the config secret' do
          should contain_podman__quadlet('iop-core-engine')
            .that_subscribes_to('Podman::Secret[iop-core-engine-config-yml]')
        end
      end
    end
  end
end
