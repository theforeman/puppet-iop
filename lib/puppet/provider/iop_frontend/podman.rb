require 'puppet/provider'
require 'fileutils'
require 'digest'
require 'tmpdir'

Puppet::Type.type(:iop_frontend).provide(:shell) do
  desc 'A provider that uses podman to install the frontend.'

  commands runtime: 'podman'

  def exists?
    desired_checksum = get_image_content_checksum

    unless File.directory?(resource[:destination])
      Puppet.debug("Destination #{resource[:destination]} not found. Resource does not exist.")
      return false
    end

    current_checksum = get_deployed_checksum

    in_sync = current_checksum == desired_checksum
    Puppet.debug("Current checksum: #{current_checksum}, Desired checksum: #{desired_checksum}. In sync: #{in_sync}")

    cleanup(nil, @staged_content_path) if in_sync

    in_sync
  end

  def create
    Puppet.info("Deploying new frontend content to '#{resource[:destination]}'")

    destroy if File.directory?(resource[:destination])

    Puppet.debug("Moving staged content from '#{@staged_content_path}' to '#{resource[:destination]}'")
    FileUtils.mv(@staged_content_path, resource[:destination])

    metadata_file = File.join(resource[:destination], '.iop_frontend_checksum')
    Puppet.debug("Writing new checksum #{@new_content_checksum} to #{metadata_file}")
    File.write(metadata_file, @new_content_checksum)

    @staged_content_path = nil
    @new_content_checksum = nil
  end

  def destroy
    Puppet.info("Removing frontend at '#{resource[:destination]}'")
    FileUtils.rm_rf(resource[:destination])
  end

  private

  def get_deployed_checksum
    metadata_file = File.join(resource[:destination], '.iop_frontend_checksum')
    return nil unless File.exist?(metadata_file)

    File.read(metadata_file).strip
  end

  def get_image_content_checksum
    return @new_content_checksum if @new_content_checksum

    temp_container_name = "iop-frontend-checker-#{resource.title.gsub(/[^0-9a-zA-Z]/, '-')}"
    staging_dir = Dir.mktmpdir('iop_frontend_check')

    begin
      execute(['podman', 'create', '--name', temp_container_name, resource[:image]])
      source_in_container = "#{temp_container_name}:#{resource[:source_path]}/."
      execute(['podman', 'cp', source_in_container, staging_dir])

      @new_content_checksum = calculate_checksum_for_path(staging_dir)
      @staged_content_path = staging_dir

      return @new_content_checksum
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
