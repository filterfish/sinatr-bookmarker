#!/usr/bin/env ruby

$:.unshift(File.expand_path(File.dirname(__FILE__)))

require 'pp'
require 'sinatra/base'
require 'multi_json'

require 'async_sinatra'
require 'rack/contrib/jsonp'

class Bookmarker < Sinatra::Base

  include Smith::Logger

  register Sinatra::Async
  use Rack::JSONP

  def initialize
    super
    logger.debug("In initialize")
  end

  apost '/bookmark', :provides => :json do

    if request.content_type && request.content_type.start_with?('application/json')
      details = MultiJson.decode(env['rack.input'].read, :symbolize_keys => true)
      if details[:uri] && details[:user]
        begin
          settings.on_bookmark(details)
          ahalt(201)
        rescue Sequel::DatabaseError => e
          ahalt 500
        end
      else
        ahalt 401
      end
    else
      ahalt 400
    end
  end
end
