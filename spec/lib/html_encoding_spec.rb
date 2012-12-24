# -*- encoding: utf-8 -*-

require 'spec_helper'
require 'html_encoding'

describe HtmlEncoding do

  before(:all) do
    @html_encoder = HtmlEncoding.new
    @test_data_path = Pathname.new(File.expand_path("../../../tests/data", __FILE__))
  end

  # it 'should properly encoding an ISO-8859-1 string' do
  #   data = @test_data_path.join('iso-8859-1', 'forum-23.html').read(:encoding => 'ASCII-8BIT')
  #   @html_encoder.encode(data)
  # end

  it 'should properly encoding a uft-8 string' do
    data = @test_data_path.join('utf-8', 'nginx-default').read(:encoding => 'ASCII-8BIT')
    @html_encoder.encode(data).should == data.encode('utf-8')
  end
end
