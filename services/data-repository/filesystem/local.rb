# encoding: utf-8 
require 'fileutils'

module DataRepository
  module Filesystem
    class Local
      DEFAULT_PREFIX = File.join(File.dirname(__FILE__), '..', 'tmp')

      def initialize(base_directory=DEFAULT_PREFIX)
        @base_directory = base_directory
      end #initialize

      def create_base_directory
        FileUtils.mkpath @base_directory unless exists? @base_directory
      end

      def store(path, data)
        FileUtils.mkpath( File.dirname( fullpath_for(path) ) )

        File.open(fullpath_for(path), 'wb') do |file|
          data.read { |chunk| file.write(chunk)}
        end if data.respond_to?(:bucket)
        
        File.open(fullpath_for(path), 'wb') do |file|
          chunk = data.gets
          while chunk
            file.write(chunk)
            chunk = data.gets
          end
        end unless data.respond_to?(:bucket)

        path
      end #store

      def fetch(path)
        File.open(fullpath_for(path), 'r')
      end #fetch

      def exists?(path)
        File.exists?(fullpath_for(path))
      end #exists?

      # Use from controlled environments always
      def remove(path)
        if exists?(path)
          File.delete(fullpath_for(path))
        end
      end

      def fullpath_for(path)
        File.join(base_directory, path)
      end #fullpath_for

      private

      attr_reader :base_directory

      def targets_for(path)
        fullpath = fullpath_for(path)
        [ 
          Dir.glob(fullpath),
          Dir.glob("#{fullpath}/*"),
          Dir.glob("#{fullpath}/**/*")
        ].flatten
          .uniq
          .delete_if { |entry| dot_directory?(entry) }
      end #targets_for

      def dot_directory?(path)
        path == '.' || path == '..'
      end #dot_directory?

      def relative_path_for(path, base_directory)
       (path.split('/') - base_directory.split('/')).join('/')
      end #relative_path_for
    end # Local
  end # Filesystem
end # DataRepository

