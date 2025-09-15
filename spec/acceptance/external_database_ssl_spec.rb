require 'spec_helper_acceptance'

describe 'external database with SSL configuration' do
  before(:all) do
    on default, 'systemctl stop iop-*'
    on default, 'rm -rf /etc/containers/systemd/*'
    on default, 'systemctl daemon-reload'
    on default, 'podman rm --all --force'
    on default, 'podman secret rm --all'
    on default, 'podman network rm iop-core-network --force'
    on default, 'dnf -y remove postgres*'
    on default, 'dnf -y remove foreman*'
    on default, 'rm -rf /tmp/ssl-test'
  end

  context 'with external database and SSL configuration' do
    it_behaves_like 'an idempotent resource' do
      let(:manifest) do
        <<-PUPPET
        # Create test SSL certificates for PostgreSQL
        file { '/tmp/ssl-test':
          ensure => directory,
          mode   => '0755',
        }

        # Create a test CA certificate
        file { '/tmp/ssl-test/ca.crt':
          ensure  => file,
          mode    => '0644',
          content => "-----BEGIN CERTIFICATE-----
MIICljCCAX4CCQCKmY+B1B5F8TANBgkqhkiG9w0BAQsFADCBjTELMAkGA1UEBhMC
VVMxCzAJBgNVBAgMAkNBMRYwFAYDVQQHDA1TYW4gRnJhbmNpc2NvMQ0wCwYDVQQK
DARUZXN0MQ0wCwYDVQQLDARUZXN0MQ0wCwYDVQQDDARUZXN0MSIwIAYJKoZIhvcN
AQkBFhN0ZXN0QGV4YW1wbGUuY29tMA0GCSqGSIb3DQEBCwUAA4IBAQCpqU7C8ZhO
-----END CERTIFICATE-----",
          require => File['/tmp/ssl-test'],
        }

        file { '/var/lib/foreman':
          ensure => directory,
        }

        file { '/var/lib/foreman/public':
          ensure => directory,
          require => File['/var/lib/foreman'],
        }

        file { '/var/lib/foreman/public/assets':
          ensure => directory,
          require => File['/var/lib/foreman/public'],
        }

        include foreman::config::apache

        # Configure IOP with external database parameters and SSL
        class { 'iop':
          register_as_smartproxy              => false,
          database_host                       => 'localhost',
          database_port                       => 5432,
          database_sslmode                    => 'verify-ca',
          database_ssl_ca                     => '/tmp/ssl-test/ca.crt',
          inventory_database_name             => 'inventory_db',
          inventory_database_user             => 'inventory_user',
          inventory_database_password         => 'test_inventory_password',
          vulnerability_database_name         => 'vulnerability_db',
          vulnerability_database_user         => 'vulnerability_admin',
          vulnerability_database_password     => 'test_vulnerability_password',
          vmaas_database_name                 => 'vmaas_db',
          vmaas_database_user                 => 'vmaas_admin',
          vmaas_database_password             => 'test_vmaas_password',
          advisor_database_name               => 'advisor_db',
          advisor_database_user               => 'advisor_user',
          advisor_database_password           => 'test_advisor_password',
          remediations_database_name          => 'remediations_db',
          remediations_database_user          => 'remediations_user',
          remediations_database_password      => 'test_remediations_password',
        }
        PUPPET
      end
    end

    describe 'SSL environment variables verification' do
      describe command('podman exec iop-service-vuln-manager printenv POSTGRES_SSL_MODE') do
        its(:stdout) { should match /verify-ca/ }
        its(:exit_status) { should eq 0 }
      end

      describe command('podman exec iop-service-vuln-manager printenv POSTGRES_SSL_ROOT_CERT_PATH') do
        its(:stdout) { should match %r{/tmp/ssl-test/ca.crt} }
        its(:exit_status) { should eq 0 }
      end

      describe command('podman exec iop-service-remediations-api printenv DB_SSL_ENABLED') do
        its(:stdout) { should match /true/ }
        its(:exit_status) { should eq 0 }
      end

      describe command('podman exec iop-service-remediations-api printenv DB_SSL_CERT') do
        its(:stdout) { should match %r{/tmp/ssl-test/ca.crt} }
        its(:exit_status) { should eq 0 }
      end
    end

    describe 'database configuration verification' do
      describe command('sudo -u postgres psql -c "SELECT datname FROM pg_database WHERE datname IN (\'inventory_db\', \'vulnerability_db\', \'vmaas_db\', \'advisor_db\', \'remediations_db\');"') do
        its(:stdout) { should match /inventory_db/ }
        its(:stdout) { should match /vulnerability_db/ }
        its(:stdout) { should match /vmaas_db/ }
        its(:stdout) { should match /advisor_db/ }
        its(:stdout) { should match /remediations_db/ }
        its(:exit_status) { should eq 0 }
      end

      describe command('sudo -u postgres psql -c "SELECT usename FROM pg_user WHERE usename IN (\'inventory_user\', \'vulnerability_admin\', \'vmaas_admin\', \'advisor_user\', \'remediations_user\');"') do
        its(:stdout) { should match /inventory_user/ }
        its(:stdout) { should match /vulnerability_admin/ }
        its(:stdout) { should match /vmaas_admin/ }
        its(:stdout) { should match /advisor_user/ }
        its(:stdout) { should match /remediations_user/ }
        its(:exit_status) { should eq 0 }
      end
    end

    describe 'service connectivity verification' do
      describe command("podman run --network=iop-core-network quay.io/iop/host-inventory curl -s -o /dev/null -w '%{http_code}' http://iop-core-host-inventory-api:8081/health") do
        its(:stdout) { should match /200/ }
      end

      describe command("podman run --network=iop-core-network quay.io/iop/vulnerability-engine curl -s -o /dev/null -w '%{http_code}' http://iop-service-vuln-manager:8000/healthz") do
        its(:stdout) { should match /200/ }
      end

      describe command("podman run --network=iop-core-network quay.io/iop/vmaas curl -s -o /dev/null -w '%{http_code}' http://iop-service-vmaas-webapp-go:8000/api/v1/version") do
        its(:stdout) { should match /200/ }
      end
    end

    describe 'SSL certificate file verification' do
      describe file('/tmp/ssl-test/ca.crt') do
        it { is_expected.to be_file }
        it { is_expected.to be_readable }
        its(:content) { should match /BEGIN CERTIFICATE/ }
        its(:content) { should match /END CERTIFICATE/ }
      end
    end

    describe 'podman secrets verification' do
      describe command('podman secret ls | grep database') do
        its(:stdout) { should match /iop-core-host-inventory-api-database/ }
        its(:stdout) { should match /iop-service-vulnerability-database/ }
        its(:stdout) { should match /iop-service-vmaas-database/ }
        its(:stdout) { should match /iop-service-advisor-database/ }
        its(:stdout) { should match /iop-service-remediations-api-database/ }
        its(:exit_status) { should eq 0 }
      end
    end

    describe 'external database connection verification' do
      describe command('podman exec iop-core-host-inventory-api-dbmigration pg_isready -h localhost -p 5432 -U inventory_user -d inventory_db') do
        its(:stdout) { should match /accepting connections/ }
        its(:exit_status) { should eq 0 }
      end

      describe command('podman exec iop-service-vuln-dbupgrade pg_isready -h localhost -p 5432 -U vulnerability_admin -d vulnerability_db') do
        its(:stdout) { should match /accepting connections/ }
        its(:exit_status) { should eq 0 }
      end
    end
  end
end