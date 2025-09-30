require 'puppet/provider'
require 'puppet/util/selinux'
require 'fileutils'
require 'digest'
require 'tmpdir'

Puppet::Type.type(:iop_frontend).provide(:shell) do
  desc 'A provider that uses podman to install the frontend.'

  include Puppet::Util::SELinux

  commands runtime: 'podman'

  def exists?
    File.exist?(metadata_file)
  end

  def image
    get_deployed_checksum.to_s
  end

  def image=(value)
    create
  end

  def create
    Puppet.info("Deploying new frontend content to '#{resource[:destination]}'")

    destroy if File.directory?(resource[:destination])

    staged_content_path, new_content_checksum = stage_content
    Puppet.debug("Copying staged content from '#{staged_content_path}' to '#{resource[:destination]}'")
    Dir.mkdir(resource[:destination], 0755)
    FileUtils.cp_r(Dir.glob(File.join(staged_content_path, '*')), resource[:destination])

    restore_selinux_context(resource[:destination])

    Puppet.debug("Writing new checksum #{new_content_checksum} to #{metadata_file}")
    File.write(metadata_file, new_content_checksum)
  end

  def destroy
    Puppet.info("Removing frontend at '#{resource[:destination]}'")
    FileUtils.rm_rf(resource[:destination])
  end

  def content_checksum
    path, checksum = stage_content
    checksum
  end

  private

  def metadata_file
    File.join(resource[:destination], '.iop_frontend_checksum')
  end

  def get_deployed_checksum
    return nil unless File.exist?(metadata_file)

    File.read(metadata_file).strip
  end

  def stage_content
    temp_container_name = "iop-frontend-checker-#{resource.title.gsub(/[^0-9a-zA-Z]/, '-')}"
    staging_dir = Dir.mktmpdir('iop_frontend_check')

    begin
      execute(['podman', 'create', '--name', temp_container_name, resource[:image]])
      source_in_container = "#{temp_container_name}:#{resource[:source_path]}/."
      execute(['podman', 'cp', source_in_container, staging_dir])

      new_content_checksum = calculate_checksum_for_path(staging_dir)
      staged_content_path = staging_dir

      return staged_content_path, new_content_checksum
    rescue Puppet::ExecutionFailure => e
      Puppet.err("Failed to get content checksum from image '#{resource[:image]}': #{e.message}")
      cleanup(temp_container_name, staging_dir)
      raise
    ensure
      cleanup(temp_container_name, nil)
    end
  end

  def calculate_checksum_for_path(path)
    files = Dir.glob(File.join(path, '**', '*'), File::FNM_DOTMATCH).select { |f| File.file?(f) }.sort
    return 'empty' if files.empty?

    content_string = files.map { |f| Digest::SHA256.file(f).hexdigest }.join
    Digest::SHA256.hexdigest(content_string)
  end

  def restore_selinux_context(path)
    return unless selinux_support?

    Puppet.debug("Restoring SELinux context for '#{path}' and its contents")

    Dir.glob(File.join(path, '**', '*')).each do |file_path|
      next if File.basename(file_path) == '.' || File.basename(file_path) == '..'

      begin
        set_selinux_default_context(file_path)
        Puppet.debug("Restored SELinux context for '#{file_path}'")
      rescue => e
        Puppet.warning("Failed to set SELinux context for '#{file_path}': #{e.message}")
      end
    end

    # Also restore context for the directory itself
    begin
      set_selinux_default_context(path)
      Puppet.debug("Restored SELinux context for '#{path}'")
    rescue => e
      Puppet.warning("Failed to set SELinux context for '#{path}': #{e.message}")
    end
  end

  def cleanup(container_name, temp_dir)
    if container_name
      Puppet.debug("Cleaning up temporary container: #{container_name}")
      if system('podman', 'container', 'exists', container_name)
        execute(['podman', 'rm', container_name], failonfail: false)
      end
    end

    if temp_dir && Dir.exist?(temp_dir)
      Puppet.debug("Cleaning up temporary directory: #{temp_dir}")
      FileUtils.rm_rf(temp_dir)
    end
  end
end
