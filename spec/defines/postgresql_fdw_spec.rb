require 'spec_helper'

describe 'iop::postgresql_fdw' do
  on_supported_os.each do |os, facts|
    context "on #{os}" do
      let(:facts) { facts }
      let(:title) { 'test' }

      let(:params) do
        {
          database_name: 'test_db',
          database_user: 'test_user',
          database_password: 'test_password',
          remote_database_name: 'inventory_db',
          remote_user: 'inventory_user',
          remote_password: 'inventory_password',
          expected_columns: "ARRAY['id','display_name']",
        }
      end

      let(:pre_condition) do
        <<-PUPPET
        include postgresql::server
        postgresql::server::db { 'test_db':
          user     => 'test_user',
          password => 'test_password',
        }
        PUPPET
      end

      context 'with required parameters' do
        it { should compile.with_all_deps }

        it { should contain_postgresql_psql('test-create_foreign_server') }
        it { should contain_postgresql_psql('test-create_user_mapping') }
        it { should contain_postgresql_psql('test-create_postgres_user_mapping') }
        it { should contain_postgresql_psql('test-grant_usage_on_foreign_server') }
        it { should contain_postgresql_psql('test-import_foreign_table') }
        it { should contain_postgresql_psql('test-create_local_view') }
        it { should contain_postgresql_psql('test-grant_foreign_table_access') }
        it { should contain_postgresql_psql('test-grant_remote_view_access') }

        it 'should drop stale foreign table when columns mismatch' do
          should contain_postgresql_psql('test-drop_stale_foreign_table')
            .with_command(%r{DROP FOREIGN TABLE IF EXISTS})
            .with_onlyif(%r{NOT EXISTS.*array_agg})
        end

        it 'should import foreign table after drop check' do
          should contain_postgresql_psql('test-import_foreign_table')
            .that_requires('Postgresql_psql[test-drop_stale_foreign_table]')
        end

        it 'should use column identity check for local view' do
          should contain_postgresql_psql('test-create_local_view')
            .with_unless(%r{array_agg\(column_name::text ORDER BY ordinal_position\)})
        end
      end
    end
  end
end
