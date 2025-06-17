Puppet::Type.newtype(:iop_frontend) do
  @doc = 'A Puppet type to manage the installation of a frontend application from a container image.'

  ensurable

  newparam(:destination, namevar: true) do
    desc 'The absolute path to the destination directory where the frontend files should be installed.'

    validate do |value|
      unless Puppet::Util.absolute_path?(value)
        raise ArgumentError, "Destination path must be absolute, not '#{value}'"
      end
    end
  end

  newparam(:image) do
    desc 'The full name of the container image to pull, including the tag (e.g., "registry.example.com/my-app:latest").'

    validate do |value|
      unless value.is_a?(String)
        raise ArgumentError, "Image must be a string, not '#{value.class}'"
      end
    end
  end

  newparam(:source_path) do
    desc 'The path inside the container from which to copy the frontend files.'
    defaultto '/srv/dist'

    validate do |value|
      unless Puppet::Util.absolute_path?(value)
        raise ArgumentError, "Source path must be absolute, not '#{value}'"
      end
    end
  end

  autorequire(:file) do
    File.dirname(self[:destination])
  end
end
