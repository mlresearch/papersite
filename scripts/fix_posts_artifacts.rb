#!/usr/bin/env ruby
# frozen_string_literal: true
# Thin wrapper around lib/tidy_posts.rb (prefer: pmlint posts --fix).
# Usage: ruby scripts/fix_posts_artifacts.rb POSTS_DIR_OR_VOLUME_DIR

require 'rbconfig'

dir = ARGV[0] or abort 'usage: fix_posts_artifacts.rb VOLUME_DIR (contains _posts/)'
vol = if File.basename(dir) == '_posts'
        File.dirname(dir)
      else
        dir
      end
exec(RbConfig.ruby, File.expand_path('../lib/tidy_posts.rb', __dir__), '-d', vol, *ARGV[1..])
