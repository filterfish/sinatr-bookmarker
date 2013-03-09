# -*- encoding: utf-8 -*-
require 'thin'
require 'sequel'
require 'em-http'

require 'bookmarker'
require 'html_encoding'

Sequel.connect('postgres:///bookmarker_development')

# Make sure this goes after the Sequel.connect line.
require 'models'

class Object
  def maybe
    unless self.nil?
      yield self
    end
  end
end

class BookmarkerPersisterAgent < Smith::Agent

  options :monitor => false

  def run
    receiver('bookmarker.ingres', :type => :bookmark_initiate).subscribe(&method(:bookmark))

    @html_encoder = HtmlEncoding.new
  end

  private

  def bookmark(payload, receiver)
    User[:token => payload.token].maybe do |user|
      document = Document[:uri => payload.uri]
      if document
        case document.status
        when 200,400..499
          user.document_downloads << DocumentDownload.create(:user_id => user.id, :document_id => document.id)
          logger.info("Document updated: [#{user.login}]: #{payload.uri}")
        when 500..599
          download_document(payload.uri, user) do |response|
            document.update_fields(response, [:uri, :redirected_uri, :status, :html])
          end
        else
          logger.error { "FIXME. Something should go here document: #{document}" }
        end
      else
        download_document(payload.uri, user) do |response|
          begin
            document = Document.create(response)
            user.document_downloads << DocumentDownload.create(:user_id => user.id, :document_id => document.id)
            user.save
          rescue Sequel::DatabaseError => e
            logger.error(e.message)
          end
        end
      end
    end
  end

  def download_document(uri, user, &blk)
    begin
      http = EM::HttpRequest.new(uri).get(:connect_timeout => 120, :inactivity_timeout => 240, :redirects => 12, :head => {"accept-encoding" => "deflate, compressed"})
      http.callback do
        logger.info("Document downloaded: [#{user.login}]: #{http.response_header.status}  #{http.last_effective_url.display_uri}")

        blk.call(:uri => uri, :redirected_uri => http.last_effective_url, :status => http.response_header.status, :html => @html_encoder.encode(http.response, http.response_header['Content-Type']))
      end

      http.errback do
        logger.info("Document could not be downloaded: [#{user.login}]: #{http.response_header.status}  #{uri}")
      end
    rescue Addressable::URI::InvalidURIError => e
      logger.error("Invalid uri: #{uri.display}")
    end
  end
end
