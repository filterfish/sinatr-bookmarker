require 'sequel'
require 'htmlcleaner'
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

    now = Time.now.utc
    self.created_at ||= now
    self.updated_at = now
    self.domain = Addressable::URI.parse(self.uri).host
    super
  end
end

class DocumentDownload < Sequel::Model
  many_to_one :documents
  many_to_one :users

  def before_create
    self.download_at = Time.now.utc
  end
end

class User < Sequel::Model
  one_to_many :document_downloads
end
