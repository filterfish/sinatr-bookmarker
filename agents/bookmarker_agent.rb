# -*- encoding: utf-8 -*-
require 'bookmarker'

class BookmarkerAgent < Smith::Agent

  options :monitor => true

  PORT = 4567

  def run
    # Be careful with this lambda. It must be a lambda (or a proc) and it also
    # runs in the context of the Bookmarker class NOT this agent.
    on_bookmark = ->(details) do
      Smith::Messaging::Sender.new('bookmarker.ingres', :auto_delete => false, :durable => true) do |queue|
        queue.publish(Smith::ACL::Factory.create(:bookmark_initiate, details))
      end
    end

    Bookmarker.run!(:bind => '127.0.0.1', :port => PORT, :on_bookmark => on_bookmark)
    logger.info { "listening on port: #{PORT}" }
  end
end
