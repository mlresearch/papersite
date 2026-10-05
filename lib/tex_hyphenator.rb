# frozen_string_literal: true

# Minimal Liang hyphenation (TeX \patterns) for English.
#
# Used by PdfWrapHyphens as an optional high-confidence *join* signal:
# if left+right is a word and the break sits on a legal hyphenation point,
# prefer join. Patterns are vendored under lib/hyphenation/ (see NOTICE).
#
# This is not a full TeX hyphenation engine (no discretionary hyphens, no
# language switching). left_min / right_min default to US English (2 / 3).
class TexHyphenator
  Pattern = Struct.new(:letters, :values)

  def initialize(patterns_path, exceptions_path: nil, left_min: 2, right_min: 3)
    @left_min = left_min
    @right_min = right_min
    @patterns = load_patterns(patterns_path)
    @exceptions = exceptions_path && File.file?(exceptions_path) ? load_exceptions(exceptions_path) : {}
  end

  # Break offsets (after how many characters) for +word+.
  def hyphenate(word)
    word = word.to_s.downcase
    return [] if word.length < @left_min + @right_min

    if (ex = @exceptions[word])
      return ex.select { |b| b >= @left_min && (word.length - b) >= @right_min }
    end

    dotted = ".#{word}."
    scores = Array.new(dotted.length + 1, 0)

    @patterns.each do |pat|
      start = 0
      while (idx = dotted.index(pat.letters, start))
        pat.values.each_with_index do |val, j|
          pos = idx + j
          scores[pos] = val if val > scores[pos]
        end
        start = idx + 1
      end
    end

    breaks = []
    (0...(word.length - 1)).each do |i|
      # score index between dotted[i+1] and dotted[i+2]
      next unless scores[i + 2].odd?
      after = i + 1
      next if after < @left_min
      next if (word.length - after) < @right_min
      breaks << after
    end
    breaks
  end

  # True when +left+ + +right+ hyphenates exactly at the boundary.
  def break_between?(left, right)
    left = left.to_s.downcase
    right = right.to_s.downcase
    return false if left.empty? || right.empty?

    word = left + right
    hyphenate(word).include?(left.length)
  end

  private

  def load_patterns(path)
    File.readlines(path, chomp: true).flat_map do |line|
      line = line.sub(/%.*\z/, '').strip
      next [] if line.empty?

      line.split.map { |token| parse_pattern(token) }
    end
  end

  def parse_pattern(token)
    letters = +''
    values = []
    num = 0
    token.each_char do |ch|
      if ch >= '0' && ch <= '9'
        num = ch.to_i
      else
        values << num
        letters << ch
        num = 0
      end
    end
    values << num
    Pattern.new(letters, values)
  end

  def load_exceptions(path)
    ex = {}
    File.foreach(path) do |line|
      line = line.sub(/%.*\z/, '').strip
      next if line.empty?

      line.split.each do |token|
        parts = token.split('-')
        word = parts.join.downcase
        breaks = []
        pos = 0
        parts[0...-1].each do |part|
          pos += part.length
          breaks << pos
        end
        ex[word] = breaks
      end
    end
    ex
  end
end
