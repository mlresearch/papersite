# frozen_string_literal: true

require_relative 'pdf_wrap_hyphens'

# Shared detectors for PDF / conversion artifacts in free-text fields
# (BibTeX abstract/title, or Jekyll _posts YAML abstract/title/author strings).
#
# Used by check_volume (intake .bib) and check_posts (published correction path)
# so both gates catch the same corruption classes.
module TextFieldArtifacts
  TEXTBACKSLASH_RE = /\\textbackslash(?:\{\}|(?![a-zA-Z]))/

  # Alphabetic Presentation Forms commonly emitted by PDF text extractors.
  PDF_EXTRACTION_LIGATURES = {
    0xFB00 => ['ﬀ', 'ff'],
    0xFB01 => ['ﬁ', 'fi'],
    0xFB02 => ['ﬂ', 'fl'],
    0xFB03 => ['ﬃ', 'ffi'],
    0xFB04 => ['ﬄ', 'ffl'],
    0xFB05 => ['ﬅ', 'st'],
    0xFB06 => ['ﬆ', 'st'],
  }.freeze

  module_function

  # Scan +text+ and return human-readable issue strings (no leading indent).
  # +field+ is a label such as "abstract" or "title".
  def issues_in(text, field:)
    return [] if text.nil?

    s = text.to_s
    return [] if s.empty?

    issues = []
    issues.concat(wrap_hyphen_issues(s, field))
    issues.concat(textbackslash_issues(s, field))
    issues.concat(ligature_issues(s, field))
    issues.concat(escaped_char_issues(s, field))
    issues.concat(double_backslash_issues(s, field))
    issues
  end

  def wrap_hyphen_issues(text, field)
    out = []
    PdfWrapHyphens.each_occurrence(text) do |left, right, _lineno, preview|
      detail = PdfWrapHyphens.decision_detail(left, right)
      action = case detail[:action]
               when :keep_hyphen then "keep hyphen (#{detail[:reason]})"
               when :drop_hyphen then "drop hyphen, keep space (#{detail[:reason]})"
               else "join (#{detail[:reason]})"
               end
      out << "#{field}: PDF wrap hyphen \"#{left}- #{right}\" — #{action}\n    Context: #{preview}"
    end
    out
  end

  def textbackslash_issues(text, field)
    return [] unless text.match?(TEXTBACKSLASH_RE)

    ["#{field}: \\textbackslash found — over-escaped backslash; use \\ instead (e.g. \\log not \\textbackslash{}log)"]
  end

  def ligature_issues(text, field)
    out = []
    text.each_char do |char|
      info = PDF_EXTRACTION_LIGATURES[char.ord]
      next unless info

      glyph, ascii = info
      hex = format('U+%04X', char.ord)
      out << "#{field}: PDF ligature #{glyph} (#{hex}) — replace with ASCII \"#{ascii}\""
    end
    out.uniq
  end

  def escaped_char_issues(text, field)
    out = []
    check = text.dup
    # \left\{ and \right\} are legitimate LaTeX math — strip before \$ \{ \} \_ scan
    check = check.gsub(/\\left\\{|\\right\\{/, '')
    check = check.gsub(/\\left\\}|\\right\\}/, '')
    [['\\$', '\$'], ['\\{', '\{'], ['\\}', '\}'], ['\\_', '\_']].each do |pat, label|
      out << "#{field}: #{label} found — should be unescaped" if check.include?(pat)
    end
    out
  end

  def double_backslash_issues(text, field)
    return [] unless text.include?('\\\\')

    ["#{field}: double backslash \\\\ found — usually a conversion artifact"]
  end
end
