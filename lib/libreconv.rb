require "libreconv/version"
require "uri"
require "net/http"
require "tmpdir"
require "spoon"

module Libreconv

  def self.convert(source, target, options = {})
    Converter.new(source, target, options).convert
  end

  class Converter
    attr_accessor :options

    def initialize(source, target, options = {})
      @options = default_options.merge(options)
      @source = source
      @target = target
      @target_path = Dir.tmpdir
      determine_soffice_command
      check_source_type
      determine_output_format
      
      unless @options[:soffice_command] && File.exists?(@options[:soffice_command])
        raise IOError, "Can't find Libreoffice or Openoffice executable."
      end
    end

    def convert
      orig_stdout = $stdout.clone
      $stdout.reopen File.new('/dev/null', 'w')
      pid = Spoon.spawnp(@options[:soffice_command], "--headless", "--convert-to",
                         @options[:convert_to], @source, "--outdir", @target_path)
      Process.waitpid(pid)
      $stdout.reopen orig_stdout
      target_tmp_file = "#{@target_path}/#{File.basename(@source, ".*")}.#{@options[:convert_to]}"
      FileUtils.cp target_tmp_file, @target
    end

    private

    def determine_soffice_command
      unless @options[:soffice_command]
        @options[:soffice_command] ||= which("soffice")
        @options[:soffice_command] ||= which("soffice.bin")
      end
    end

    def determine_output_format
      unless @options[:convert_to]
        @options[:convert_to] = File.extname(@target)[1..-1]
        if @options[:convert_to].nil? || @options[:convert_to].empty?
          @options[:convert_to] = 'pdf' #default to pdf if no file extension
        end
      end
    end

    def which(cmd)
      exts = ENV['PATHEXT'] ? ENV['PATHEXT'].split(';') : ['']
      ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
        exts.each do |ext|
          exe = File.join(path, "#{cmd}#{ext}")
          return exe if File.executable? exe
        end
      end
    
      return nil
    end

    def check_source_type
      is_file = File.exists?(@source) && !File.directory?(@source)
      is_http = URI(@source).scheme == "http" && Net::HTTP.get_response(URI(@source)).is_a?(Net::HTTPSuccess)
      is_https = URI(@source).scheme == "https" && Net::HTTP.get_response(URI(@source)).is_a?(Net::HTTPSuccess)  
      raise IOError, "Source (#{@source}) is neither a file nor an URL." unless is_file || is_http || is_https
    end

    def default_options
      {
          soffice_command: nil, # try to auto-determine,
          convert_to: nil, # try to auto-determine from output filename
      }
    end
  end
end