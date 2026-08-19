# Shared BibTeX citekey checks for check_volume.rb and create_volume.rb.
#
# Non-ASCII keys are dropped silently by bibtex-ruby during parse, so the
# volume pipeline must refuse them before generation. Keys are identifiers:
# they must be renamed in the source .bib, not rewritten by unicode tidying.

module BibTeXKeys
  class InvalidKeyError < StandardError; end

  # Capture the citekey of each @InProceedings entry (case-insensitive).
  ENTRY_KEY_RE = /@InProceedings\s*\{\s*([^\s,]+)\s*,/i

  def self.keys(content)
    content.scan(ENTRY_KEY_RE).flatten
  end

  def self.non_ascii_keys(content)
    keys(content).select { |k| k.match?(/[^\x00-\x7F]/) }
  end

  def self.assert_valid_keys!(content)
    bad = non_ascii_keys(content)
    return if bad.empty?

    listed = bad.map { |k| "  Non-ASCII character in key: '#{k}'" }.join("\n")
    raise InvalidKeyError,
          "ERROR: Invalid BibTeX keys (rename to ASCII before processing):\n#{listed}"
  end

  def self.abort_if_invalid!(bib_file)
    assert_valid_keys!(File.read(bib_file, encoding: 'UTF-8'))
  rescue InvalidKeyError => e
    STDERR.puts e.message
    exit 1
  end

  # Keys present in the source that did not survive BibTeX.parse.
  def self.dropped_keys(content, parsed_keys)
    keys(content) - parsed_keys.map(&:to_s)
  end
end
