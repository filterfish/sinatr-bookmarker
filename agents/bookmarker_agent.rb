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

class BookmarkerAgent < Smith::Agent

  options :monitor => true

  def run
    on_bookmark = proc do |details|
      Smith::Messaging::Sender.new('bookmarker.ingres', :auto_delete => false, :durable => true).ready do |queue|
        queue.publish(Smith::ACL::Payload.new(:bookmark_initiate).content(details))
      end
    end

    Bookmarker.run!(:port => 4567, :on_bookmark => on_bookmark)
  end
end
