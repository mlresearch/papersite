#!/usr/bin/env ruby

require 'test/unit'
require_relative '../lib/bibtex_keys'

class TestBibTeXKeys < Test::Unit::TestCase
  FIXTURES = File.expand_path('../tests/fixtures', __dir__)

  def test_v328_lists_non_ascii_keys
    content = File.read(File.join(FIXTURES, 'v328_original', 'CPAL26.bib'), encoding: 'UTF-8')
    bad = BibTeXKeys.non_ascii_keys(content)
    assert_includes bad, 'miñoza26'
    assert_includes bad, 'schrödter26'
  end

  def test_v328_assert_raises_and_names_keys
    content = File.read(File.join(FIXTURES, 'v328_original', 'CPAL26.bib'), encoding: 'UTF-8')
    err = assert_raises(BibTeXKeys::InvalidKeyError) do
      BibTeXKeys.assert_valid_keys!(content)
    end
    assert_match(/Non-ASCII character in key: 'miñoza26'/, err.message)
    assert_match(/Non-ASCII character in key: 'schrödter26'/, err.message)
  end

  def test_clean_volume_keys_are_ascii
    content = File.read(File.join(FIXTURES, 'clean_volume', 'proceedings.bib'), encoding: 'UTF-8')
    assert_equal [], BibTeXKeys.non_ascii_keys(content)
    assert_nothing_raised { BibTeXKeys.assert_valid_keys!(content) }
  end

  def test_dropped_keys_detects_parse_omission
    content = <<~BIB
      @InProceedings{kept26a,
        title = {Kept},
        author = {Smith, John},
      }
      @InProceedings{missing26a,
        title = {Missing},
        author = {Doe, Jane},
      }
    BIB
    dropped = BibTeXKeys.dropped_keys(content, ['kept26a'])
    assert_equal ['missing26a'], dropped
  end
end
