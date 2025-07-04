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

options = OptionParser.new do |opts|
  opts.banner = "Usage: #{$0} <volume> <bibfile> [options]"
  opts.on("--verbose", "Enable verbose output") do
    verbose = true
  end
  opts.on("--quiet", "Suppress all output") do
    quiet = true
    verbose = false
  end
end

if ARGV.length < 2
  puts options.banner
else
  options.parse!(ARGV)
  volume = ARGV[0]
  bib_filename = ARGV[1]
  bib_file = MLResearch.procdir + volume + '/' + bib_filename

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
  MLResearch.extractpapers(bib_file, volume, volume_info, nil, nil, nil, nil, verbose && !quiet, quiet)
  out = File.open('index.html', 'w')
  out.puts "---"
  out.puts "layout: home"
  out.puts "---"
end
