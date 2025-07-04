#!/usr/bin/env ruby

require 'yaml'
require 'unicode/name'
require 'optparse'

options = { accept_all: false, strict: false, verbose: false, quiet: false }
OptionParser.new do |opts|
  opts.banner = "Usage: ruby tidy_bib_unicode.rb input.bib [output_clean.bib] [options]"
  opts.on("--accept-all", "Automatically accept all proposed substitutions (no prompt)") do
    options[:accept_all] = true
  end
  opts.on("--strict", "Fail with error if a substitution is missing") do
    options[:strict] = true
  end
  opts.on("--verbose", "Print extra information during processing") do
    options[:verbose] = true
  end
  opts.on("--quiet", "Suppress all non-essential output, including summary") do
    options[:quiet] = true
  end
end.parse!(ARGV)

if ARGV.length < 1
  puts "Usage: ruby tidy_bib_unicode.rb input.bib [output_clean.bib] [--accept-all] [--strict] [--verbose] [--quiet]"
  exit 1
end

input_file = ARGV[0]
output_file = ARGV[1] || input_file.sub(/\.bib$/, '_clean.bib')
UNICODE_REPLACEMENTS_FILE = File.expand_path('../../unicode_replacements.yml', __FILE__)

def load_replacements
  if File.exist?(UNICODE_REPLACEMENTS_FILE)
    YAML.load_file(UNICODE_REPLACEMENTS_FILE) || {}
  else
    {}
  end
end

def sanitize_replacement(str)
  str.to_s.strip.gsub(/[
\n]+/, "")
end

def save_replacements(replacements)
  # Double all backslashes in replacement strings before saving to YAML
  replacements_to_save = {}
  replacements.each do |char, val|
    if val.is_a?(Hash) && val['replacement']
      rep = sanitize_replacement(val['replacement']).gsub('\\', '\\\\')
      replacements_to_save[char] = val.merge('replacement' => rep)
    elsif val.is_a?(String)
      rep = sanitize_replacement(val).gsub('\\', '\\\\')
      replacements_to_save[char] = rep
    else
      replacements_to_save[char] = val
    end
  end
  File.open(UNICODE_REPLACEMENTS_FILE, 'w') { |f| f.write(replacements_to_save.to_yaml) }
end

def unicode_name(char)
  Unicode::Name.of(char) rescue nil
end

def get_replacement(char, replacements, options)
  name = unicode_name(char) || 'UNKNOWN'
  if replacements.key?(char)
    default = sanitize_replacement(replacements[char].is_a?(Hash) ? replacements[char]['replacement'] : replacements[char])
    if options[:accept_all]
      return default
    else
      loop do
        print "Unicode character '#{char}' (#{name}) detected. Suggested replacement: '#{default}'. Press Enter to accept or type a new replacement: "
        input = $stdin.gets.strip
        replacement = input.empty? ? default : sanitize_replacement(input)
        if replacement.include?(char)
          puts "[WARNING] Replacement contains the original character. Please provide a replacement that does not include '#{char}'."
          next
        end
        # Save new replacement if not already present
        if !replacements.key?(char) || (replacements[char].is_a?(Hash) ? replacements[char]['replacement'] : replacements[char]) != replacement
          replacements[char] = {'replacement' => replacement, 'name' => name}
          save_replacements(replacements)
        end
        return replacement
      end
    end
  else
    if options[:accept_all] || options[:strict]
      if options[:strict]
        STDERR.puts "[ERROR] No substitution found for Unicode character '#{char}' (#{name}) in strict mode."
        exit 2
      else
        STDERR.puts "[WARNING] No substitution found for Unicode character '#{char}' (#{name}). Skipping in accept-all mode."
        return char # leave as is
      end
    else
      loop do
        print "Unicode character '#{char}' (#{name}) detected. Please provide a replacement: "
        input = $stdin.gets.strip
        replacement = sanitize_replacement(input)
        if replacement.include?(char)
          puts "[WARNING] Replacement contains the original character. Please provide a replacement that does not include '#{char}'."
          next
        end
        # Save new replacement if not already present
        if !replacements.key?(char) || (replacements[char].is_a?(Hash) ? replacements[char]['replacement'] : replacements[char]) != replacement
          replacements[char] = {'replacement' => replacement, 'name' => name}
          save_replacements(replacements)
        end
        return replacement
      end
    end
  end
end

unless File.exist?(input_file)
  puts "Input file not found: #{input_file}"
  exit 1
end

# First, scan the file for all unique unicode characters
unicode_chars = []
File.foreach(input_file) do |line|
  unicode_chars.concat(line.scan(/[^\u0000-\u007F]/))
end
unicode_chars.uniq!

if options[:verbose]
  puts "Input file: #{input_file}"
  puts "Output file: #{output_file}"
  puts "Using replacements file: #{UNICODE_REPLACEMENTS_FILE}"
end

if unicode_chars.empty?
  puts "No Unicode characters found. No changes made."
  File.write(output_file, File.read(input_file)) unless output_file == input_file
  exit 0
end

if options[:verbose]
  puts "Found the following Unicode characters:"
  unicode_chars.each do |char|
    puts "  '#{char}' (#{unicode_name(char) || 'UNKNOWN'})"
  end
end
replacements = load_replacements
replacement_map = {}
unicode_chars.each do |char|
  replacement = get_replacement(char, replacements, options)
  replacement = sanitize_replacement(replacement)
  replacement_map[char] = replacement
  puts "[DEBUG] Replacement for '#{char}' (#{unicode_name(char) || 'UNKNOWN'}): '#{replacement}'"
  if options[:verbose]
    puts "[VERBOSE] Replacement for '#{char}' (#{unicode_name(char) || 'UNKNOWN'}): '#{replacement}'"
  end
end

# Now process the file line by line and write to output
pattern = Regexp.union(replacement_map.keys)
File.open(output_file, 'w') do |outf|
  File.foreach(input_file) do |line|
    if options[:verbose]
      matches = line.scan(pattern)
      matches.each do |char|
        puts "[VERBOSE] Replacing '#{char}' with '#{replacement_map[char]}' in line: #{line.strip}"
      end
    end
    line = line.gsub(pattern) { |char| replacement_map[char] }
    outf.write(line)
  end
end

if options[:verbose]
  puts "Cleaned file written to #{output_file}"
  puts "Replacements used:"
  replacement_map.each do |char, replacement|
    puts "  '#{char}' (#{unicode_name(char) || 'UNKNOWN'}) => '#{replacement}'"
  end
elsif !options[:quiet]
  unless replacement_map.empty?
    summary = replacement_map.map { |char, replacement| "#{char}->#{replacement}" }.join(", ")
    puts "#{replacement_map.size} replacements made: [#{summary}]"
  end
end 