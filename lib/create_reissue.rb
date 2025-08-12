#!/usr/bin/env ruby

require 'rubygems'
require 'bibtex'
require 'yaml'
require 'facets'
require 'latex/decode'
require 'fileutils'
require 'pandoc-ruby'
require_relative 'mlresearch'
require 'optparse'

procdir = '/Users/neil/mlresearch/'

verbose = false
quiet = false
skip_pdf_check = false

options = OptionParser.new do |opts|
  opts.banner = "Usage: #{$0} <volume> <bibfile> [options]"
  opts.separator ""
  opts.separator "Arguments:"
  opts.separator "  volume     The volume number (e.g., v288)"
  opts.separator "  bibfile    The bib file containing paper information"
  opts.separator ""
  opts.separator "Options:"
  opts.on("--verbose", "Enable verbose output") do
    verbose = true
  end
  opts.on("--quiet", "Suppress all output") do
    quiet = true
    verbose = false
  end
  opts.on("--skip-pdf-check", "Skip PDF file existence checks (useful when PDFs are in separate branch)") do
    skip_pdf_check = true
  end
  opts.on("-h", "--help", "Show this help message") do
    puts opts
    exit
  end
end

begin
  options.parse!(ARGV)
rescue OptionParser::InvalidOption, OptionParser::MissingArgument => e
  STDERR.puts "Error: #{e.message}"
  STDERR.puts options
  exit 1
end

# Validate required arguments
if ARGV.length < 2
  STDERR.puts "Error: Missing required arguments."
  STDERR.puts options
  exit 1
end

volume = ARGV[0]
bib_filename = ARGV[1]

# Validate volume format
unless volume.match?(/^[vr]\d+$/)
  STDERR.puts "Error: Volume must be in format 'v<number>' or 'r<number>' (e.g., v288, r42)"
  STDERR.puts options
  exit 1
end

bib_file = MLResearch.procdir + volume + '/' + bib_filename

# Check if bib file exists
unless File.exist?(bib_file)
  STDERR.puts "Error: Bib file '#{bib_file}' does not exist."
  STDERR.puts "Make sure the file exists in the volume directory: #{MLResearch.procdir}#{volume}/"
  STDERR.puts options
  exit 1
end

# Run tidy_bib_unicode.rb on the bib file, output to a temp cleaned file
cleaned_bib_file = bib_file.sub(/\.bib$/, '_clean.bib')
tidy_cmd = "ruby #{File.expand_path('tidy_bib_unicode.rb', __dir__)} \"#{bib_file}\" \"#{cleaned_bib_file}\" --accept-all --strict"
tidy_cmd += " --verbose" if verbose && !quiet
tidy_cmd += " --quiet" if quiet
puts "Running: #{tidy_cmd}" if verbose && !quiet
system(tidy_cmd)
unless File.exist?(cleaned_bib_file)
  STDERR.puts "[ERROR] Cleaned bib file was not created. Exiting."
  exit 1
end
bib_file = cleaned_bib_file

volume_info = MLResearch.bibextractconfig(bib_file, volume, nil, nil, verbose && !quiet, quiet)
MLResearch.write_volume_files(volume_info)
directory_name = "_posts"
Dir.mkdir(directory_name) unless File.exists?(directory_name)
MLResearch.extractpapers(bib_file, volume, volume_info, nil, nil, nil, nil, verbose && !quiet, quiet, skip_pdf_check)
out = File.open('index.html', 'w')
out.puts "---"
out.puts "layout: home"
out.puts "---"
