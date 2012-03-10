require 'bookmarker'
require 'thin'
require 'sequel'

Sequel.connect('postgres:///bookmarker_development')

# Make sure this goes after the Sequel.connect line.
require 'models'

class BookmarkerAgent < Smith::Agent

  def run
    receiver('bookmarker.ingres') do |r|
      r.payload.tap do |details|
        user = User[:login => details[:user]]
        document = Document[:uri => details[:uri]] || Document.create(:uri => details[:uri], :title => details[:title], :html => details[:content])
        user.document_downloads << DocumentDownload.create(:download_at => Time.now.utc, :user_id => user.id, :document_id => document.id)
        user.save
      end
    end

    on_bookmark = proc do |details|
      Smith::Messaging::Sender.new('bookmarker.ingres', :auto_delete => false, :durable => true).ready do |queue|
        queue.publish(Smith::ACL::Payload.new.content(details))
      end
    end

    Bookmarker.run!(:port => 4567, :on_bookmark => on_bookmark)
  end
end
