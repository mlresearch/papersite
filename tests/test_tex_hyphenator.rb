#!/usr/bin/env ruby
# frozen_string_literal: true

# Regression tests for TexHyphenator + PdfWrapHyphens TeX join signal,
# YAML load failures, and the fix() rewriter.
# Run: ruby tests/test_tex_hyphenator.rb

require 'set'
require 'tmpdir'
require_relative '../lib/tex_hyphenator'
require_relative '../lib/pdf_wrap_hyphens'

ERRORS = []

def assert(name, cond)
  if cond
    puts "  ✓ #{name}"
    true
  else
    puts "  ✗ #{name}"
    ERRORS << name
    false
  end
end

def assert_eq(name, got, want)
  assert("#{name} (got=#{got.inspect} want=#{want.inspect})", got == want)
end

def assert_raises(name, pattern)
  begin
    yield
    assert("#{name} (expected raise matching #{pattern.inspect})", false)
  rescue StandardError => e
    assert("#{name} (#{e.class}: #{e.message})", e.message.match?(pattern))
  end
end

MINIMAL_YAML = <<~YAML
  function_left:
    - to
  compound_right:
    - supervised
  tex_hyphenation:
    enabled: false
YAML

puts '=== TexHyphenator ==='
pat = File.expand_path('../lib/hyphenation/hyph-en-us.pat.txt', __dir__)
hyp = File.expand_path('../lib/hyphenation/hyph-en-us.hyp.txt', __dir__)
h = TexHyphenator.new(pat, exceptions_path: hyp)

assert_eq 'knowledge breaks', h.hyphenate('knowledge'), [5]
assert 'knowl|edge break', h.break_between?('knowl', 'edge')
assert 'opti|mal break', h.break_between?('opti', 'mal')
assert 're|lationship break', h.break_between?('re', 'lationship')
assert 'in|variant break', h.break_between?('in', 'variant')
assert 'no to|program break', !h.break_between?('to', 'program')
assert_eq 'exception ta-ble', h.hyphenate('table'), [2]

puts
puts '=== PdfWrapHyphens + TeX ==='
PdfWrapHyphens.reload!
assert 'tex hyphenator loaded', !PdfWrapHyphens.tex_hyphenator.nil?

assert_eq 'knowl- edge → join/tex', PdfWrapHyphens.decision_detail('knowl', 'edge'),
          { action: :join, reason: 'tex_hyphenation' }
assert_eq 'in- variant → join/tex (overrides function_left)',
          PdfWrapHyphens.decision_detail('in', 'variant'),
          { action: :join, reason: 'tex_hyphenation' }
assert_eq 'the- oretical → join/tex',
          PdfWrapHyphens.decision_detail('the', 'oretical')[:action], :join
assert_eq 'to- program → drop (function_left)',
          PdfWrapHyphens.decision_detail('to', 'program')[:action], :drop_hyphen
assert_eq 'semi- supervised → keep (compound_right)',
          PdfWrapHyphens.decision_detail('semi', 'supervised')[:action], :keep_hyphen
assert_eq 'state- of-the-art → keep',
          PdfWrapHyphens.decision_detail('state', 'of-the-art')[:action], :keep_hyphen
assert_eq 'co- occurrence → keep',
          PdfWrapHyphens.decision_detail('co', 'occurrence')[:action], :keep_hyphen
assert_eq 'co- ordinate → join',
          PdfWrapHyphens.decision_detail('co', 'ordinate')[:action], :join
assert_eq 'heterogene- ity--- → join (em-dash run)',
          PdfWrapHyphens.decision_detail('heterogene', 'ity---')[:action], :join
assert_eq 'state- of- → keep (mid-compound trailing hyphen)',
          PdfWrapHyphens.decision_detail('state', 'of-')[:action], :keep_hyphen
assert_eq 'per- forms → join (forms not compound_right)',
          PdfWrapHyphens.decision_detail('per', 'forms')[:action], :join
assert_eq 'closed- form → keep',
          PdfWrapHyphens.decision_detail('closed', 'form')[:action], :keep_hyphen
assert_eq 'well- known → keep',
          PdfWrapHyphens.decision_detail('well', 'known')[:action], :keep_hyphen
assert_eq 'fix heterogene- ity---',
          PdfWrapHyphens.fix('heterogene- ity---the')[0], 'heterogeneity---the'

puts
puts '=== Fail-open without TeX ==='
ENV['PMLR_DISABLE_TEX_HYPHEN'] = '1'
PdfWrapHyphens.reload!
assert 'tex hyphenator disabled', PdfWrapHyphens.tex_hyphenator.nil?
assert_eq 'knowl- edge still joins when TeX off',
          PdfWrapHyphens.decision('knowl', 'edge'), :join
# Without TeX, function_left applies to in- variant (less ideal, documented fail-open)
assert_eq 'in- variant drops when TeX off',
          PdfWrapHyphens.decision('in', 'variant'), :drop_hyphen
ENV.delete('PMLR_DISABLE_TEX_HYPHEN')
PdfWrapHyphens.reload!

puts
puts '=== fix() rewriter ==='
input = <<~BIB
  abstract = {To our knowl- edge this is state- of-the-art and semi- supervised.
  Also in- variant theory and a to- program note, plus co- occurrence and co- ordinate.}
BIB
fixed, n = PdfWrapHyphens.fix(input)
assert 'fix count > 0', n > 0
assert 'fix joins knowledge', fixed.include?('knowledge')
assert 'fix keeps state-of-the-art', fixed.include?('state-of-the-art')
assert 'fix keeps semi-supervised', fixed.include?('semi-supervised')
assert 'fix joins invariant (TeX)', fixed.include?('invariant')
assert 'fix drops to-program hyphen', fixed.include?('to program')
assert 'fix keeps co-occurrence', fixed.include?('co-occurrence')
assert 'fix joins coordinate', fixed.include?('coordinate')
assert 'fix leaves no letter- space lowercase', !fixed.match?(/[A-Za-z]- [a-z]/)
# Multi-pass: spaced compound fragments collapse
multi_in = 'state- of- the- art methods'
multi_out, multi_n = PdfWrapHyphens.fix(multi_in)
assert_eq 'multi-pass state-of-the-art', multi_out, 'state-of-the-art methods'
assert 'multi-pass needed more than one substitution', multi_n >= 2

puts
puts '=== YAML load failures ==='
assert 'compound_right non-empty', !PdfWrapHyphens.compound_right.empty?
assert 'function_left non-empty', !PdfWrapHyphens.function_left.empty?

Dir.mktmpdir('wrap_hyphen_yaml') do |dir|
  missing = File.join(dir, 'does-not-exist.yml')
  assert_raises('missing YAML raises', /Missing .*does-not-exist\.yml/) do
    PdfWrapHyphens.with_config_path(missing) { PdfWrapHyphens.reload! }
  end

  malformed = File.join(dir, 'malformed.yml')
  File.write(malformed, "function_left: [\n  - to\ncompound_right: [")
  assert_raises('malformed YAML raises', /YAML error loading/) do
    PdfWrapHyphens.with_config_path(malformed) { PdfWrapHyphens.reload! }
  end

  not_mapping = File.join(dir, 'list.yml')
  File.write(not_mapping, "- just\n- a\n- list\n")
  assert_raises('non-mapping YAML raises', /expected a mapping/) do
    PdfWrapHyphens.with_config_path(not_mapping) { PdfWrapHyphens.reload! }
  end

  empty_compound = File.join(dir, 'empty_compound.yml')
  File.write(empty_compound, <<~YAML)
    function_left:
      - to
    compound_right: []
  YAML
  assert_raises('empty compound_right raises', /compound_right must be a non-empty list/) do
    PdfWrapHyphens.with_config_path(empty_compound) { PdfWrapHyphens.reload! }
  end

  missing_function = File.join(dir, 'no_function.yml')
  File.write(missing_function, <<~YAML)
    compound_right:
      - supervised
  YAML
  assert_raises('missing function_left raises', /function_left must be a non-empty list/) do
    PdfWrapHyphens.with_config_path(missing_function) { PdfWrapHyphens.reload! }
  end

  # Valid alternate config still loads (and TeX can be disabled there)
  ok = File.join(dir, 'ok.yml')
  File.write(ok, MINIMAL_YAML)
  PdfWrapHyphens.with_config_path(ok) do
    PdfWrapHyphens.reload!
    assert_eq 'minimal config function_left', PdfWrapHyphens.function_left, ['to'].to_set
    assert_eq 'minimal config compound_right', PdfWrapHyphens.compound_right, ['supervised'].to_set
    assert 'minimal config disables TeX', PdfWrapHyphens.tex_hyphenator.nil?
  end
end

# Ensure production config restored after with_config_path
PdfWrapHyphens.reload!
assert 'production config restored', PdfWrapHyphens.compound_right.include?('occurrence')
assert 'production TeX restored', !PdfWrapHyphens.tex_hyphenator.nil?

puts
if ERRORS.empty?
  puts 'OK — all TeX hyphenation / wrap-hyphen decision tests passed'
  exit 0
else
  puts "FAILED: #{ERRORS.size}"
  ERRORS.each { |e| puts "  - #{e}" }
  exit 1
end
