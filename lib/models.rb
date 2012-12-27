# -*- encoding: utf-8 -*-
require 'sequel'
require 'html_cleaner'
require 'addressable/uri'

Sequel.connect('postgres:///bookmarker_development')

class Document < Sequel::Model
  one_to_many :document_downloads

  def before_create
    if self.html
      cleaner = HtmlCleaner.new(self.html)
      self.html = cleaner.html
      self.content = cleaner.content
      self.title = cleaner.title
    end

    self.domain = Addressable::URI.parse(self.uri).host
    super
  end
end

class DocumentDownload < Sequel::Model
  many_to_one :documents
  many_to_one :users
end

class User < Sequel::Model
  one_to_many :document_downloads
end
