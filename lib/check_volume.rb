#!/usr/bin/env ruby

# =============================================================================
# check_volume.rb - Pre-publication validation for PMLR volumes
# =============================================================================
#
# Checks a volume directory is ready for publication:
#   1. @Proceedings entry has required fields with correct formatting
#   2. All BibTeX keys have matching PDF files in the root directory
#   3. No PDFs stranded in subdirectories
#   4. Supplementary files are in the root (not in subdirectories)
#   5. Author names are well-formed (Surname, Given format, no all-lowercase)
#   6. No double backslashes in any field
#   7. No escaped \$ \{ \} \_ in abstracts/titles
#   7b. No \textbackslash{} in abstracts/titles (over-escaped "\" → should be \log etc.)
#   8. No non-ASCII characters in BibTeX keys
#   9. No double-quote delimited fields containing \" (silently drops entries in bibtex-ruby)
#  10. No double-braced pages fields (e.g. pages = {{4-24}} renders with literal braces)
#  11. No non-printable C0/C1 control characters in text fields (mojibake, PDF
#      extraction artifacts) — UTF-8 code-point aware, so legitimate multi-byte
#      punctuation (em dash, curly quotes, etc.) is not flagged
#  12. No Unicode presentation-form ligatures (ﬀ ﬁ ﬂ ﬃ ﬄ …) — classic PDF
#      text-extraction artifacts; replace with ASCII ff/fi/fl/ffi/ffl
#  13. No PDF line-wrap hyphens ("knowl- edge", "state- of-the-art") — ASCII
#      hyphen with a following space mid-token from PDF text extraction;
#      fix with tidy_bibtex --fix-wrap-hyphens
#  14. Proper names / acronyms in titles are LaTeX-braced when listed in
#      lib/proper_names.yml (CIP-000B); unknown all-caps tokens warn and can be
#      offered for addition to the YAML (--add-proper-names)
#  15. Sectioned proceedings: if @Proceedings has sections = {A|B|…}, every
#      @InProceedings must have section matching a declared name exactly
#      (site filters by exact string; mismatches hide papers — v350)
#
# Usage:
#   ruby check_volume.rb -v VOLUME -d DIRECTORY [-b BIBFILE] [--add-proper-names]

require 'optparse'
require 'set'
require 'yaml'
require_relative 'bibtex_keys'
require_relative 'pdf_wrap_hyphens'
require_relative 'text_field_artifacts'

# =============================================================================
# Colours
# =============================================================================

module Colour
  def self.red(s)    "\e[31m#{s}\e[0m" end
  def self.green(s)  "\e[32m#{s}\e[0m" end
  def self.yellow(s) "\e[33m#{s}\e[0m" end
  def self.bold(s)   "\e[1m#{s}\e[0m"  end
  def self.cyan(s)   "\e[36m#{s}\e[0m" end
end

# =============================================================================
# Checker
# =============================================================================

class VolumeChecker

  # published is set at publication time, not required at submission/lint
  REQUIRED_PROCEEDINGS_FIELDS = %w[name shortname year editor start end address volume]
  SUPP_PATTERN = /-supp\.(pdf|zip|tar\.gz)$/i
  PDF_PATTERN  = /\.pdf$/i
  PROPER_NAMES_PATH = File.expand_path('proper_names.yml', __dir__)

  # Venue / boilerplate all-caps — do not suggest adding these to the YAML.
  ACRONYM_NOISE = %w[
    II III IV VI IX XI XII USA UK EU PDF URL HTTP HTTPS ISBN DOI IEEE ACM
    NIPS ICML ICLR AISTATS UAI AAAI IJCAI CVPR ECCV ICCV ACL EMNLP NeurIPS
    PMLR JMLR arXiv ARXIV CORL RSS IROS ICRA COLT ALT MIDL CHIL CoRL
  ].to_set

  PDF_EXTRACTION_LIGATURES = TextFieldArtifacts::PDF_EXTRACTION_LIGATURES

  def initialize(options)
    @options   = options
    @vol_dir   = options[:directory]
    @volume    = options[:volume]
    @errors    = []
    @warnings  = []
    @ok        = []
    @unknown_acronyms = Hash.new(0) # stem => count
  end

  # ---------------------------------------------------------------------------
  # Entry point
  # ---------------------------------------------------------------------------

  def run
    puts Colour.bold("=" * 60)
    puts Colour.bold("  PMLR Volume #{@volume} Pre-publication Check")
    puts Colour.bold("=" * 60)
    puts "  Directory: #{@vol_dir}"

    bib_path = find_bib_file
    unless bib_path
      fatal "No BibTeX file found in #{@vol_dir}"
    end
    puts "  BibTeX:    #{File.basename(bib_path)}"
    puts

    content = File.read(bib_path, encoding: 'utf-8')

    check_proceedings_entry(content)
    check_section_fields(content)
    check_pdf_locations
    check_supp_locations
    check_pdf_bib_match(content)
    check_author_names(content)
    check_double_backslashes(content)
    check_escaped_chars(content)
    check_textbackslash(content)
    check_non_ascii_keys(content)
    check_dq_fields_with_latex_umlauts(content)
    check_double_braced_pages(content)
    check_non_printable_characters(content)
    check_pdf_extraction_ligatures(content)
    check_pdf_wrap_hyphens(content)
    check_proper_name_bracing(content)

    print_summary
    maybe_add_proper_names
    @errors.empty? ? 0 : 1
  end

  # ---------------------------------------------------------------------------
  # Individual checks
  # ---------------------------------------------------------------------------

  def check_proceedings_entry(content)
    section "Proceedings entry"

    unless content =~ /@Proceedings\s*\{/i
      error "No @Proceedings entry found"
      return
    end

    # Extract the proceedings block (roughly)
    proc_match = content.match(/@Proceedings\s*\{[^,]+,(.*?)^\}/im)
    unless proc_match
      error "Could not parse @Proceedings block"
      return
    end
    block = proc_match[1]

    REQUIRED_PROCEEDINGS_FIELDS.each do |field|
      if block =~ /^\s*#{field}\s*=/i
        ok "  #{field} present"
      else
        error "  Missing required field: #{field}"
      end
    end

    # volume should be in braces
    if block =~ /volume\s*=\s*\{/i
      ok "  volume wrapped in braces"
    elsif block =~ /volume\s*=/i
      error "  volume value not wrapped in braces (e.g. volume = {304})"
    end

    # published is optional at submission; editors set it when publishing.
    # If present, it must be YYYY-MM-DD (empty published = {} is still an error).
    if block =~ /published\s*=\s*\{(\d{4}-\d{2}-\d{2})\}/i
      ok "  published date format OK (#{$1})"
    elsif block =~ /published\s*=/i
      error "  published field present but not in YYYY-MM-DD format"
    else
      ok "  published not set (OK at submission; set YYYY-MM-DD when publishing)"
    end
  end

  # When @Proceedings declares sections, every paper's section= value must
  # match a declared name exactly. The published site filters by that string;
  # near-misses (e.g. "Full paper" vs "Full Papers") leave headings empty.
  def check_section_fields(content)
    section "Sectioned proceedings"

    declared = extract_declared_sections(content)
    papers = extract_inproceedings_sections(content)

    if declared.nil?
      with_section = papers.select { |_k, s| s && !s.strip.empty? }
      if with_section.empty?
        ok "  Not a sectioned volume (no sections field)"
      else
        with_section.each do |key, sec|
          error "  [#{key}] has section = {#{sec}} but @Proceedings has no sections field"
        end
      end
      return
    end

    if declared.empty?
      error "  sections field is empty — remove it or list names separated by |"
      return
    end

    ok "  Declared sections: #{declared.join(' | ')}"
    counts = Hash.new(0)

    papers.each do |key, sec|
      if sec.nil? || sec.strip.empty?
        error "  [#{key}] missing section (volume declares: #{declared.join(', ')})"
      elsif !declared.include?(sec)
        error "  [#{key}] section = {#{sec}} does not match declared sections " \
              "(#{declared.join(', ')}) — exact match required or the paper will not appear"
      else
        counts[sec] += 1
      end
    end

    declared.each do |name|
      n = counts[name]
      if n.zero?
        error "  Declared section #{name.inspect} has no papers — heading will be empty on the site"
      else
        ok "  #{name}: #{n} paper(s)"
      end
    end
  end

  def extract_declared_sections(content)
    proc_match = content.match(/@Proceedings\s*\{[^,]+,(.*?)^\}/im)
    return nil unless proc_match
    block = proc_match[1]
    return nil unless block =~ /^\s*sections\s*=/i

    raw = braced_field_value(block, 'sections')
    return [] if raw.nil?

    raw.split('|').map { |part| part.split('=', 2).first.to_s.strip }.reject(&:empty?)
  end

  def extract_inproceedings_sections(content)
    papers = []
    content.scan(/@InProceedings\s*\{\s*([\w-]+)\s*,/i) do
      key = Regexp.last_match(1)
      start = Regexp.last_match.end(0)
      block = entry_body_from(content, start)
      papers << [key, braced_field_value(block, 'section')]
    end
    papers
  end

  # Body of a BibTeX entry starting after the opening "key," through the
  # matching top-level closing brace (exclusive).
  def entry_body_from(content, start)
    slice = content[start, 200_000] || ''
    depth = 1
    end_idx = slice.length
    prev = nil
    slice.each_char.with_index do |ch, idx|
      if ch == '{' && prev != '\\'
        depth += 1
      elsif ch == '}' && prev != '\\'
        depth -= 1
        if depth.zero?
          end_idx = idx
          break
        end
      end
      prev = ch
    end
    slice[0...end_idx]
  end

  def braced_field_value(block, field)
    m = block.match(/^\s*#{Regexp.escape(field)}\s*=\s*\{/i)
    return nil unless m

    start = m.end(0)
    slice = block[start, 50_000] || ''
    depth = 1
    end_idx = 0
    prev = nil
    slice.each_char.with_index do |ch, idx|
      if ch == '{' && prev != '\\'
        depth += 1
      elsif ch == '}' && prev != '\\'
        depth -= 1
        if depth.zero?
          end_idx = idx
          break
        end
      end
      prev = ch
    end
    slice[0...end_idx].gsub(/\s+/, ' ').strip
  end

  def check_pdf_locations
    section "PDF file locations"

    root_pdfs = Dir.glob(File.join(@vol_dir, '*.pdf'))
                   .reject { |f| File.basename(f) =~ SUPP_PATTERN }
    ok "  #{root_pdfs.size} PDF(s) in root"

    subdirs_with_pdfs = []
    Dir.glob(File.join(@vol_dir, '*/')).each do |subdir|
      next if File.basename(subdir) == 'assets'
      next if File.basename(subdir) =~ /permissions?$/i
      pdfs = Dir.glob(File.join(subdir, '**', '*.pdf'))
                 .reject { |f| File.basename(f) =~ SUPP_PATTERN }
      subdirs_with_pdfs << [File.basename(subdir), pdfs.size] if pdfs.any?
    end

    if subdirs_with_pdfs.empty?
      ok "  No PDFs stranded in subdirectories"
    else
      subdirs_with_pdfs.each do |dir, count|
        error "  #{count} PDF(s) in subdirectory '#{dir}/' — move to root"
      end
    end
  end

  def check_supp_locations
    section "Supplementary file locations"

    root_supps = Dir.glob(File.join(@vol_dir, '*-supp.*'))
    if root_supps.any?
      ok "  #{root_supps.size} supplementary file(s) in root"
    else
      warn_msg "  No supplementary files found (OK if none submitted)"
    end

    subdirs_with_supps = []
    Dir.glob(File.join(@vol_dir, '*/')).each do |subdir|
      next if File.basename(subdir) == 'assets'
      supps = Dir.glob(File.join(subdir, '**', '*-supp.*'))
      subdirs_with_supps << [File.basename(subdir), supps.size] if supps.any?
    end

    if subdirs_with_supps.empty?
      ok "  No supplementary files stranded in subdirectories"
    else
      subdirs_with_supps.each do |dir, count|
        error "  #{count} supplementary file(s) in subdirectory '#{dir}/' — move to root"
      end
    end
  end

  def check_pdf_bib_match(content)
    section "BibTeX key / PDF file match"

    keys = content.scan(/@InProceedings\s*\{\s*([\w-]+)\s*,/i).flatten
    root_pdfs = Dir.glob(File.join(@vol_dir, '*.pdf'))
                   .map { |f| File.basename(f, '.pdf') }
                   .reject { |f| f =~ /-supp$/ }
                   .to_set

    missing_pdfs = keys.reject { |k| root_pdfs.include?(k) }
    extra_pdfs   = root_pdfs - keys.to_set

    ok "  #{keys.size} BibTeX entries, #{root_pdfs.size} root PDF(s)"

    if missing_pdfs.empty?
      ok "  All BibTeX keys have a matching PDF"
    else
      missing_pdfs.each { |k| error "  Missing PDF for key: #{k}" }
    end

    if extra_pdfs.empty?
      ok "  No extra PDFs without a BibTeX entry"
    else
      extra_pdfs.each { |p| warn_msg "  Extra PDF with no BibTeX entry: #{p}.pdf" }
    end
  end

  def check_author_names(content)
    section "Author name formatting"

    issues = []

    # Extract each entry key and its full author field value.
    # Author fields can span multiple lines; we collect everything between
    # 'author = {' and the matching closing brace.
    entry_positions = []
    content.scan(/@\w+\s*\{\s*([\w-]+)\s*,/i) { entry_positions << [$~.begin(0), $1] }
    entry_positions.sort_by!(&:first)
    entry_idx = 0

    content.scan(/author\s*=\s*\{/i) do
      author_pos = $~.begin(0)
      start = $~.end(0)
      # Advance to the latest entry that starts at or before this author field (O(n) total).
      while entry_idx + 1 < entry_positions.length && entry_positions[entry_idx + 1][0] <= author_pos
        entry_idx += 1
      end
      key = entry_positions[entry_idx] ? entry_positions[entry_idx][1] : '?'

      # Walk a bounded slice with each_char. Indexing a UTF-8 String with [] is
      # O(n) per access in Ruby, so content[i] over a 10MB file is unusable.
      slice = content[start, 50_000] || ''
      depth = 1
      end_idx = 0
      prev = nil
      slice.each_char.with_index do |ch, idx|
        if ch == '{' && prev != '\\'
          depth += 1
        elsif ch == '}' && prev != '\\'
          depth -= 1
          if depth == 0
            end_idx = idx
            break
          end
        end
        prev = ch
      end
      author_val = slice[0...end_idx].gsub(/\s+/, ' ').strip

      author_val.split(/\s+and\s+/i).each do |part|
        part = part.strip
        next if part.empty?
        next if part =~ /\A\{[^{}]*(\{[^{}]*\}[^{}]*)?\}\z/  # organisation name wrapped in braces

        if part !~ /,/
          issues << "  [#{key}] No comma in name: '#{part}'"
        elsif part[0] =~ /[a-z]/
          # BibTeX "von Last, First" format: lowercase words at the start are
          # valid von-prefixes (da, van, van der, d', etc.) as long as the
          # surname part contains at least one word starting with an uppercase
          # letter (the actual Last name). Only flag if every word before the
          # comma is lowercase — that indicates a genuine uncapitalised surname.
          surname_part = part.split(',', 2).first.strip
          words = surname_part.split(/[\s']+/).reject(&:empty?)
          unless words.any? { |w| w[0] =~ /[A-Z]/ }
            issues << "  [#{key}] Lowercase surname: '#{part}'"
          end
        end
      end
    end

    if issues.empty?
      ok "  All author names appear well-formed"
    else
      issues.each { |i| error i }
    end
  end

  def check_double_backslashes(content)
    section "Double backslashes"

    lines_with_double = []
    entry_re = /(@\w+)\s*\{\s*([\w-]+)\s*,/i
    current_key = nil

    content.each_line.with_index(1) do |line, lineno|
      if (m = line.match(entry_re))
        current_key = m[2]
      end
      if line.include?('\\\\')
        lines_with_double << "  [#{current_key}] line #{lineno}: #{line.strip[0..80]}"
      end
    end

    if lines_with_double.empty?
      ok "  No double backslashes found"
    else
      lines_with_double.each { |l| error l }
    end
  end

  def check_escaped_chars(content)
    section "Escaped \\$, \\{, \\}, \\_ in abstracts/titles"

    issues = []
    current_key = nil
    in_field = false
    entry_re = /(@\w+)\s*\{\s*([\w-]+)\s*,/i

    content.each_line.with_index(1) do |line, lineno|
      if (m = line.match(entry_re))
        current_key = m[2]
      end

      in_field = true  if line =~ /^\s*(abstract|title)\s*=/i
      in_field = false if in_field && line.strip.end_with?('},')

      if in_field
        [['\\$', '\$'], ['\\{', '\{'], ['\\}', '\}'], ['\\_', '\_']].each do |pat, label|
          # \left\{ and \right\{ / \right\} are legitimate LaTeX math commands — skip them
          check_line = line
          check_line = check_line.gsub(/\\left\\{|\\right\\{/, '') if pat == '\\{'
          check_line = check_line.gsub(/\\left\\}|\\right\\}/, '') if pat == '\\}'
          if check_line.include?(pat)
            issues << "  [#{current_key}] line #{lineno}: #{label} found — should be unescaped"
          end
        end
      end
    end

    if issues.empty?
      ok "  No escaped \\$, \\{, \\}, \\_ found in abstracts/titles"
    else
      issues.uniq.each { |i| error i }
    end
  end

  def check_textbackslash(content)
    section "Over-escaped \\textbackslash in abstracts/titles"

    # Conversion artifact: a literal "\" was written as the LaTeX command
    # \textbackslash{} (e.g. $O(\textbackslash{}log n)$ instead of $O(\log n)$).
    # Distinct from double-backslash checks — this is a single-backslash command.
    # Fix: tidy_bibtex --fix-textbackslash  or  pmlint --fix
    issues = []
    current_key = nil
    in_field = false
    entry_re = /(@\w+)\s*\{\s*([\w-]+)\s*,/i

    content.each_line.with_index(1) do |line, lineno|
      if (m = line.match(entry_re))
        current_key = m[2]
      end

      in_field = true  if line =~ /^\s*(abstract|title)\s*=/i
      in_field = false if in_field && line.strip.end_with?('},')

      next unless in_field
      next unless line.match?(TextFieldArtifacts::TEXTBACKSLASH_RE)

      issues << "  [#{current_key || '?'}] line #{lineno}: \\textbackslash found — over-escaped backslash; use \\ instead (e.g. \\log not \\textbackslash{}log)"
    end

    if issues.empty?
      ok "  No \\textbackslash over-escaping found in abstracts/titles"
    else
      issues.uniq.each { |i| error i }
    end
  end

  def check_non_ascii_keys(content)
    section "BibTeX key characters"

    bad_keys = BibTeXKeys.non_ascii_keys(content)

    if bad_keys.empty?
      ok "  All BibTeX keys are ASCII"
    else
      bad_keys.each { |k| error "  Non-ASCII character in key: '#{k}'" }
    end
  end

  def check_dq_fields_with_latex_umlauts(content)
    section "Double-quote fields containing LaTeX umlauts"

    # Fields like  author = "... K\"ustner ..."  use " as delimiter but also
    # contain \"  (LaTeX umlaut command).  bibtex-ruby interprets the \" as
    # closing the field, silently truncating the entry — the paper is then not
    # generated by create_volume.rb even though check_volume counts the PDF.
    # Fix: change those field delimiters from "..." to {...}.
    issues = []
    current_key = nil
    entry_re = /(@\w+)\s*\{\s*([\w-]+)\s*,/i

    content.each_line.with_index(1) do |line, lineno|
      if (m = line.match(entry_re))
        current_key = m[2]
      end
      # Match any field that uses double-quote delimiters and contains \"
      # e.g.  author = "... K\"ustner ..."
      if line =~ /^\s*\w+\s*=\s*"[^"]*\\"/
        field_name = line[/^\s*(\w+)\s*=/, 1]
        issues << "  [#{current_key}] line #{lineno}: #{field_name} field uses \" delimiter with \\\" inside — change to {...}"
      end
    end

    if issues.empty?
      ok "  No double-quote fields with LaTeX umlauts found"
    else
      issues.each { |i| error i }
    end
  end

  def check_double_braced_pages(content)
    section "Double-braced pages fields"

    # pages = {{4-24}} is a common LaTeX export mistake. bibtex-ruby preserves the
    # inner braces, so create_volume.rb renders firstpage/lastpage with literal { }.
    issues = []
    current_key = nil
    entry_re = /(@\w+)\s*\{\s*([\w-]+)\s*,/i

    content.each_line.with_index(1) do |line, lineno|
      if (m = line.match(entry_re))
        current_key = m[2]
      end

      if line =~ /^\s*pages\s*=\s*\{\{/
        issues << "  [#{current_key}] line #{lineno}: pages field uses double braces (e.g. {{4-24}}) — use single braces: {4-24}"
      end
    end

    if issues.empty?
      ok "  No double-braced pages fields found"
    else
      issues.each { |i| error i }
    end
  end

  def check_non_printable_characters(content)
    section "Non-printable characters"

    # Scan decoded Unicode code points (not raw bytes) so legitimate multi-byte
    # UTF-8 punctuation — em dash U+2014, curly quotes U+201C/U+201D, etc. —
    # is not flagged just because its UTF-8 continuation bytes fall in 0x80–0xBF.
    # Tab (U+0009), LF (U+000A), and CR (U+000D) are allowed; all other C0/C1
    # controls are rejected. This catches:
    #   - PDF line-break artifacts like U+0002 (v316)
    #   - Mojibake C1 controls like U+0080/U+009D (v283)
    issues = []
    current_key = nil
    entry_re = /(@\w+)\s*\{\s*([\w-]+)\s*,/i

    content.each_line.with_index(1) do |line, lineno|
      if (m = line.match(entry_re))
        current_key = m[2]
      end

      line.each_char do |char|
        cp = char.ord
        next if cp == 0x09 || cp == 0x0A || cp == 0x0D
        if cp <= 0x1F || (0x7F..0x9F).cover?(cp)
          hex = format('U+%04X', cp)
          issues << "  [#{current_key || '?'}] line #{lineno}: non-printable character #{hex} — check for mis-encoded Unicode (mojibake) or a stray extraction artifact"
        end
      end
    end

    if issues.empty?
      ok "  No non-printable characters found"
    else
      issues.uniq.each { |i| error i }
    end
  end

  def check_pdf_extraction_ligatures(content)
    section "PDF extraction ligatures"

    # Presentation-form ligatures (U+FB00–FB06) almost always mean the abstract
    # was copied from a PDF that used a ligature glyph. Fail explicitly rather
    # than waiting for create_volume's unicode tidy (or relying on --unicode).
    issues = []
    current_key = nil
    entry_re = /(@\w+)\s*\{\s*([\w-]+)\s*,/i

    content.each_line.with_index(1) do |line, lineno|
      if (m = line.match(entry_re))
        current_key = m[2]
      end

      line.each_char do |char|
        info = PDF_EXTRACTION_LIGATURES[char.ord]
        next unless info
        glyph, ascii = info
        hex = format('U+%04X', char.ord)
        issues << "  [#{current_key || '?'}] line #{lineno}: PDF ligature #{glyph} (#{hex}) — replace with ASCII \"#{ascii}\" (common PDF text-extraction artifact)"
      end
    end

    if issues.empty?
      ok "  No PDF extraction ligatures found"
    else
      issues.uniq.each { |i| error i }
    end
  end

  def check_pdf_wrap_hyphens(content)
    section "PDF line-wrap hyphens"

    # ASCII "letter- lowercase" almost always means a PDF line-break hyphen was
    # kept and the newline became a space. Genuine en dashes are Unicode or
    # LaTeX -- / --- and do not match this pattern. Auto-fix via:
    #   ruby lib/tidy_bibtex.rb --fix-wrap-hyphens INPUT OUTPUT
    #   pmlint --fix
    issues = []
    current_key = nil
    entry_re = /(@\w+)\s*\{\s*([\w-]+)\s*,/i
    key_at_line = {}

    content.each_line.with_index(1) do |line, lineno|
      if (m = line.match(entry_re))
        current_key = m[2]
      end
      key_at_line[lineno] = current_key
    end

    PdfWrapHyphens.each_occurrence(content) do |left, right, lineno, preview|
      key = key_at_line[lineno] || '?'
      detail = PdfWrapHyphens.decision_detail(left, right)
      action = case detail[:action]
               when :keep_hyphen then "keep hyphen (#{detail[:reason]})"
               when :drop_hyphen then "drop hyphen, keep space (#{detail[:reason]})"
               else "join (#{detail[:reason]})"
               end
      issues << "  [#{key}] line #{lineno}: PDF wrap hyphen \"#{left}- #{right}\" — #{action}; fix with tidy_bibtex --fix-wrap-hyphens\n    Context: #{preview}"
    end

    if issues.empty?
      ok "  No PDF line-wrap hyphens found"
    else
      issues.each { |i| error i }
    end
  end

  def check_proper_name_bracing(content)
    section "Proper-name / acronym bracing in titles (CIP-000B)"

    stems = load_proper_name_stems
    if stems.nil?
      warn_msg "  Could not load #{PROPER_NAMES_PATH} — skipping"
      return
    end
    if stems.empty?
      warn_msg "  No stems in proper_names.yml — skipping"
      return
    end

    titles = extract_title_fields(content)
    if titles.empty?
      ok "  No title fields to check"
      return
    end

    known_set = stems.to_set
    issues = []
    titles.each do |key, title, lineno|
      stems.each do |stem|
        next if title_stem_protected?(title, stem)
        next unless title_stem_plain?(title, stem)
        hint = if stem == stem.upcase && stem.length >= 2
                 "{#{stem}}"
               else
                 "{#{stem[0]}}#{stem[1..]} or {#{stem}}"
               end
        issues << "  [#{key}] line #{lineno}: unprotected #{stem.inspect} in title — use #{hint}"
      end
      scan_unknown_acronyms(title, known_set).each do |acro|
        @unknown_acronyms[acro] += 1
      end
    end

    if issues.empty?
      ok "  All listed proper names/acronyms in titles are braced (#{stems.size} stems, #{titles.size} titles)"
    else
      issues.uniq.each { |i| error i }
    end

    if @unknown_acronyms.empty?
      ok "  No unknown all-caps acronym candidates outside proper_names.yml"
    else
      @unknown_acronyms.sort_by { |a, n| [-n, a] }.each do |acro, n|
        warn_msg "  unknown acronym #{acro.inspect} (#{n}×) — not in proper_names.yml" \
                 " (re-run with --add-proper-names to append)"
      end
      puts Colour.yellow("  Suggested YAML entries:")
      @unknown_acronyms.keys.sort.each do |acro|
        puts Colour.yellow("    - stem: #{acro}")
        puts Colour.yellow("      kind: acronym")
      end
    end
  end

  def load_proper_name_stems
    return [] unless File.file?(PROPER_NAMES_PATH)
    data = YAML.safe_load(File.read(PROPER_NAMES_PATH), aliases: true)
    return [] unless data.is_a?(Hash) && data['stems'].is_a?(Array)
    data['stems'].map { |e| e.is_a?(Hash) ? e['stem'].to_s : e.to_s }.reject(&:empty?)
  rescue Psych::SyntaxError, Psych::DisallowedClass => e
    warn_msg "  YAML error loading proper_names.yml: #{e.message}"
    nil
  end

  def extract_title_fields(content)
    # [[key, title, lineno], ...]
    out = []
    entry_positions = []
    content.scan(/@\w+\s*\{\s*([\w-]+)\s*,/i) { entry_positions << [$~.begin(0), $1] }
    entry_positions.sort_by!(&:first)
    entry_idx = 0

    content.scan(/title\s*=\s*\{/i) do
      title_pos = $~.begin(0)
      lineno = content[0...title_pos].count("\n") + 1
      start = $~.end(0)
      while entry_idx + 1 < entry_positions.length && entry_positions[entry_idx + 1][0] <= title_pos
        entry_idx += 1
      end
      key = entry_positions[entry_idx] ? entry_positions[entry_idx][1] : '?'

      slice = content[start, 50_000] || ''
      depth = 1
      end_idx = 0
      prev = nil
      slice.each_char.with_index do |ch, idx|
        if ch == '{' && prev != '\\'
          depth += 1
        elsif ch == '}' && prev != '\\'
          depth -= 1
          if depth == 0
            end_idx = idx
            break
          end
        end
        prev = ch
      end
      title = slice[0...end_idx]
      next if title.nil? || title.strip.empty?
      # Skip proceedings booktitle-as-title noise: only InProceedings-ish keys
      # still check all titles including proceedings if present — fine.
      out << [key, title, lineno]
    end
    out
  end

  def title_stem_protected?(title, stem)
    return false if stem.nil? || stem.empty?
    # {Bayes} or {SVM}
    return true if title.match?(/\{#{Regexp.escape(stem)}\}/)
    # {B}ayes — first letter braced, remainder follows immediately
    return true if stem.length >= 2 && title.match?(/\{#{Regexp.escape(stem[0])}\}#{Regexp.escape(stem[1..])}\b/)
    false
  end

  def title_stem_plain?(title, stem)
    return false if stem.nil? || stem.empty?
    title.match?(/\b#{Regexp.escape(stem)}\b/)
  end

  def scan_unknown_acronyms(title, known_set)
    # Remove already-braced acronyms / {X}REST so we only see unprotected caps
    stripped = title.gsub(/\{[A-Z]{2,}\}/, ' ')
    stripped = stripped.gsub(/\{[A-Z]\}[A-Z]+/, ' ')
    stripped.scan(/\b([A-Z]{2,})\b/).flatten.uniq.reject do |a|
      known_set.include?(a) || ACRONYM_NOISE.include?(a) || a.length > 12
    end
  end

  def maybe_add_proper_names
    return if @unknown_acronyms.empty?
    return unless @options[:add_proper_names]

    unless File.file?(PROPER_NAMES_PATH)
      warn_msg "  --add-proper-names: #{PROPER_NAMES_PATH} missing"
      return
    end

    candidates = @unknown_acronyms.keys.sort
    puts
    puts Colour.bold("  Add unknown acronyms to proper_names.yml?")
    to_add = []
    candidates.each do |acro|
      n = @unknown_acronyms[acro]
      print "    Add #{acro} (#{n}×)? [y/N/a(all)/q(quit)] "
      unless $stdin.tty?
        puts "(non-interactive — skip; pass stems via future non-TTY API)"
        break
      end
      ans = $stdin.gets
      break if ans.nil?
      ans = ans.strip.downcase
      case ans
      when 'q' then break
      when 'a'
        to_add = candidates
        break
      when 'y', 'yes'
        to_add << acro
      end
    end

    return if to_add.empty?

    existing = load_proper_name_stems || []
    existing_set = existing.to_set
    added = []
    File.open(PROPER_NAMES_PATH, 'a') do |f|
      to_add.each do |acro|
        next if existing_set.include?(acro)
        f.write("\n  - stem: #{acro}\n    kind: acronym\n")
        existing_set << acro
        added << acro
      end
    end
    if added.empty?
      puts Colour.yellow("  Nothing new to add (already present).")
    else
      puts Colour.green("  Appended to #{PROPER_NAMES_PATH}: #{added.join(', ')}")
    end
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  def find_bib_file
    if @options[:bibfile]
      path = File.join(@vol_dir, @options[:bibfile])
      return File.exist?(path) ? path : nil
    end
    Dir.glob(File.join(@vol_dir, '*.bib'))
       .reject { |f| f =~ /_clean\.bib$/ }
       .first
  end

  def section(title)
    puts Colour.cyan("  ── #{title}")
  end

  def ok(msg)
    puts Colour.green("  ✓") + " #{msg}"
    @ok << msg
  end

  def warn_msg(msg)
    puts Colour.yellow("  ⚠") + " #{msg}"
    @warnings << msg
  end

  def error(msg)
    puts Colour.red("  ✗") + " #{msg}"
    @errors << msg
  end

  def fatal(msg)
    puts Colour.red("FATAL: #{msg}")
    exit 1
  end

  def print_summary
    puts
    puts Colour.bold("=" * 60)
    puts Colour.bold("  Summary")
    puts Colour.bold("=" * 60)
    puts Colour.green("  Passed:   #{@ok.size}")
    puts Colour.yellow("  Warnings: #{@warnings.size}")
    puts Colour.red("  Errors:   #{@errors.size}")
    puts

    if @errors.empty?
      puts Colour.green(Colour.bold("  ✓ Volume #{@volume} is ready for publication."))
    else
      puts Colour.red(Colour.bold("  ✗ #{@errors.size} issue(s) must be fixed before publication."))
      puts
      puts Colour.bold("  Issues:")
      @errors.each { |e| puts Colour.red("    - #{e.strip}") }
    end
    puts
  end
end

# =============================================================================
# CLI
# =============================================================================

options = {}

OptionParser.new do |opts|
  opts.banner = "Usage: check_volume.rb -v VOLUME -d DIRECTORY [-b BIBFILE] [--add-proper-names]"

  opts.on('-v', '--volume VOLUME', 'Volume number') { |v| options[:volume] = v }
  opts.on('-d', '--directory DIR', 'Path to volume directory') { |d| options[:directory] = d }
  opts.on('-b', '--bibfile FILE',  'BibTeX filename (auto-detected if omitted)') { |b| options[:bibfile] = b }
  opts.on('--add-proper-names', 'Interactively append unknown acronyms to lib/proper_names.yml') do
    options[:add_proper_names] = true
  end
  opts.on('-h', '--help', 'Show this help') { puts opts; exit }
end.parse!

%i[volume directory].each do |req|
  unless options[req]
    warn "ERROR: --#{req} is required"
    exit 1
  end
end

unless Dir.exist?(options[:directory])
  warn "ERROR: Directory '#{options[:directory]}' does not exist"
  exit 1
end

exit VolumeChecker.new(options).run
