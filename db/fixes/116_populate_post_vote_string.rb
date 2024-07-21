#!/usr/bin/env ruby
# frozen_string_literal: true

require File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "config", "environment"))

Post.without_timeout do
  Post.find_each do |post|
    post.with_lock do
      puts post.id
      post.update_column(:vote_string, post.votes.map { |x| "#{%w[down locked up].fetch(x.score + 1)}:#{x.user_id}" }.join(" "))
      post.clean_vote_string!
    end
  end
end
