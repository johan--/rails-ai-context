# frozen_string_literal: true

module RailsAiContext
  # Safe file reading with size limits and error handling.
  # Returns String on success, nil on any failure (missing, too large, unreadable).
  # Designed as a drop-in replacement for unguarded File.read calls across
  # introspectors and tools where nil is already handled.
  module SafeFile
    def self.read(path, max_size: nil)
      return nil unless path && File.file?(path)

      limit = max_size || RailsAiContext.configuration.max_file_size
      return nil if File.size(path) > limit

      File.read(path, encoding: "UTF-8", invalid: :replace, undef: :replace)
    rescue Errno::ENOENT, Errno::EACCES, Errno::EISDIR, Errno::ENAMETOOLONG, SystemCallError
      nil
    end
  end
end
