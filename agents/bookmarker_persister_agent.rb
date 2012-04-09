require 'bookmarker'
require 'thin'
require 'sequel'
require 'em-http'

Sequel.connect('postgres:///bookmarker_development')

# Make sure this goes after the Sequel.connect line.
require 'models'

class Object
  def maybe
    if !self.nil?
      yield self
    end
  end
end

class BookmarkerPersisterAgent < Smith::Agent

  options :monitor => false

  def run
    receiver('bookmarker.ingres', :type => :bookmark_initiate, &method(:bookmark))
  end

  private

  def download_document(uri, &blk)
    logger.debug("Downloading: #{uri}")

    http = EM::HttpRequest.new(uri).get(:connect_timeout => 60, :inactivity_timeout => 240, :redirects => 12, :head => {"accept-encoding" => "gzip, compressed"})
    http.callback do
      logger.info("Document downloaded: #{http.response_header.status}  #{http.last_effective_url.to_s}")
      blk.call(:uri => uri, :redirected_uri => http.last_effective_url, :status => http.response_header.status, :html => http.response)
    end

    http.errback do
      logger.warn("Document could not be downloaded: #{uri}")
    end
  end

  def bookmark(receiver)
    details = receiver.payload

    User[:token => details.token].maybe do |user|
      document = Document[:uri => details.uri]
      if document
        case document.status
        when 200,400..499
          user.document_downloads << DocumentDownload.create(:user_id => user.id, :document_id => document.id)
          logger.info("DocumentDownload updated: [#{user.login}]: #{details.uri}")
        when 500..599
          download_document(details.uri) do |response|
            document.update_fields(response, [:uri, :redirected_uri, :status, :html])
          end
        end
      else
        download_document(details.uri) do |response|
          document = Document.create(response)
          user.document_downloads << DocumentDownload.create(:user_id => user.id, :document_id => document.id)
          user.save
        end
      end
    end
  end
end
