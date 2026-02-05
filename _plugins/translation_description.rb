#!/usr/bin/env ruby

Jekyll::Hooks.register :posts, :pre_render do |post|
  if post.data['original']
    author_name = post.data['original']['author']['name']
    post_title = post.data['original']['post']['title']
    post.data['description'] = "Вольный перевод поста #{author_name} \"#{post_title}\""
  end
end
