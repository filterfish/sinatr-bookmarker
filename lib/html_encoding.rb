#!/usr/bin/env ruby
# -*- encoding: utf-8 -*-

require 'set'

class HtmlEncoding

  def initialize
    @encodings = Set.new(Encoding.name_list)
    @encoding_args = {:invalid => :replace, :undef => :replace, :replace => ' '}
  end

  def encode(doc, content_type=nil)
    hint = encoding_from_content_type(content_type)
    encoding = (@encodings.include?(hint)) ? hint : html_encoding?(doc.force_encoding('ASCII-8BIT')[0..1024])
    utf8_encode(doc.force_encoding('ASCII-8BIT'), encoding)
  end

  # Encode the string as utf8 based on the input type or it that is nil
  # just convert it to utf-8 according to the ruby encoding rules.
  def utf8_encode(doc, from=nil)
    (from.nil?) ? doc.encode('utf-8', @encoding_args) : doc.encode('utf-8', from, @encoding_args)
  end

  # Atempt to extract the encoding from the Content-Type metatag.
  def html_encoding?(html)
    chunk = html[0..1024]

    charset = nil
    chunk.split(/\n/).each do |l|
      m = /Content-Type.*"(.*?)"/i.match(l)
      if m && m[1]
        return encoding_from_content_type(m[1])
      end
    end
    nil
  end

  def encoding_from_content_type(type)
    if type
      m = /charset *= *(.*)/i.match(type)
      m && m[1]
    end
  end
end
