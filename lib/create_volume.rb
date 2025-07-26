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

volume_no = nil
volume_type = nil
volume_prefix = ''
bib_file=nil
video_file=nil
software_file=nil
reponame=nil
supp_file = nil
supp_name = nil
verbose = false
quiet = false
interactive = false

parser = OptionParser.new do |parser|
  parser.banner = "Usage: create_volume.rb -v VOLUME -b BIBFILE [options]"
  parser.on("-v", "--volume VOLUME", Integer,
            "Write the specific VOLUME of PMLR") do |number|
    volume_no=number
    volume_type="Volume"
    volume_prefix = "v"
  end
  parser.on("-r", "--reissue VOLUME", Integer,
            "Write the specific VOLUME of PMLR") do |number|
    volume_no=number
    volume_type="Reissue"
    volume_prefix = "r"
  end
  parser.on("-b", "--bibfile BIBFILE", String,
            "The bib file containing information about the papers") do |filename|
    bib_file=filename
  end
  parser.on("-s", "--software-file filename", String,
            "A csv file containing information about software links") do |filename|
    software_file=filename
  end
  parser.on("-V", "--video-file filename", String,
            "A csv file containing information about video links") do |filename|
    video_file=filename
  end
  parser.on("-S", "--supplementary-file filename", String,
            "A csv file containing information about supplementary links") do |filename|
    supp_file=filename
    supp_name = 'Supplementary Material'
  end
  parser.on("-l", "--label supplementary_label", String,
            "A csv file containing information about supplementary label") do |label|
    supp_name=label
  end
  parser.on("--verbose", "Enable verbose output") do
    verbose = true
  end
  parser.on("--quiet", "Suppress all output") do
    quiet = true
    verbose = false
  end
  parser.on("--interactive", "Prompt for Unicode character substitutions (default: auto-accept)") do
    interactive = true
  end
  parser.on("-h", "--help", "Show this help message") do
    puts parser
    exit
  end
end

begin
  parser.parse!
rescue OptionParser::InvalidOption, OptionParser::MissingArgument => e
  STDERR.puts "Error: #{e.message}"
  STDERR.puts parser
  exit 1
end

# Validate required arguments
if volume_no.nil?
  STDERR.puts "Error: Volume number is required. Use -v or -r option."
  STDERR.puts parser
  exit 1
end

if bib_file.nil?
  STDERR.puts "Error: Bib file is required. Use -b option."
  STDERR.puts parser
  exit 1
end

# Check if bib file exists
unless File.exist?(bib_file)
  STDERR.puts "Error: Bib file '#{bib_file}' does not exist."
  STDERR.puts parser
  exit 1
end

reponame = volume_prefix + volume_no.to_s
if not supp_file.nil?
  supp_file = MLResearch.procdir + reponame + '/' + supp_file
end
if not video_file.nil?
  video_file = MLResearch.procdir + reponame + '/' + video_file
end
if not bib_file.nil?
  bib_file = bib_file
  puts "Debug: bib_file = #{bib_file}" if verbose && !quiet
  puts "Debug: File exists? #{File.exist?(bib_file)}" if verbose && !quiet
  puts "Debug: Current directory: #{Dir.pwd}" if verbose && !quiet

  # Run tidy_bib_unicode.rb on the bib file, output to a temp cleaned file
  cleaned_bib_file = bib_file.sub(/\.bib$/, '_clean.bib')
  tidy_cmd = "ruby #{File.expand_path('tidy_bib_unicode.rb', __dir__)} \"#{bib_file}\" \"#{cleaned_bib_file}\""
  tidy_cmd += " --accept-all --strict" unless interactive
  tidy_cmd += " --verbose" if verbose && !quiet
  tidy_cmd += " --quiet" if quiet
  puts "Running: #{tidy_cmd}" if verbose && !quiet
  system(tidy_cmd)
  unless File.exist?(cleaned_bib_file)
    STDERR.puts "[ERROR] Cleaned bib file was not created. Exiting."
    exit 1
  end
  bib_file = cleaned_bib_file
end
if not software_file.nil?
  software_file = MLResearch.procdir + reponame + '/' + software_file
end


# Write the _config.yml file
volume_info = MLResearch.bibextractconfig(bib_file, volume_no, volume_type, volume_prefix, verbose && !quiet, quiet)
MLResearch.write_volume_files(volume_info)

# Write the papers
directory_name = "_posts"
Dir.mkdir(directory_name) unless File.exist?(directory_name)
# TK should have a way of deciding whether papers are to be stored RAW or in the GH-pages
MLResearch.extractpapers(bib_file, volume_no, volume_info, software_file, video_file, supp_file, supp_name, verbose && !quiet, quiet)  
out = File.open('index.html', 'w')
out.puts "---"
out.puts "layout: home"
out.puts "---"

