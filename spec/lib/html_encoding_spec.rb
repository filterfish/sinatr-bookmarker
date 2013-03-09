# -*- encoding: utf-8 -*-

require 'spec_helper'
require 'html_encoding'

TEST_DATA_PATH = Pathname.new(File.expand_path("../../data", __FILE__))

describe HtmlEncoding do

  def test_file(file)
    TEST_DATA_PATH.join(file).read(:encoding => 'ASCII-8BIT')
  end

  before(:all) do
    @html_encoder = HtmlEncoding.new
  end

  it 'should properly encoding an ISO-8859-1 string' do
    @html_encoder.encode(test_file('iso-8859-1/forum-23.html'))
  end

  it 'should properly encoding a uft-8 string' do
    data = test_file('utf-8/nginx-default')
    @html_encoder.encode(data).should == data.encode('utf-8')

    data = test_file('utf-8/10-best-jquery-datepickers-plugins')
    @html_encoder.encode(data).should == data.encode('utf-8', {:invalid => :replace, :undef => :replace, :replace => '?'})
  end
end
