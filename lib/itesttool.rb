# coding: utf-8
require 'rubygems'
require 'net/http'
require 'uri'
require 'json'
require 'jsonpath'
require 'nokogiri'
require "itesttool/version"
require "itesttool/custom_matchers"

def _given(&b) before(:each, &b) end
def _when(&b) let(:res, &b) end
def _then(&b) it(&b) end

module ItestHelpers

  def as_text() "text" end
  def as_json() "json" end
  def as_xml() "xml" end
  def as_html() "html" end

  alias res_is_json as_json
  alias res_is_xml as_xml
  alias res_is_html as_html

  def headers(h = {})
    @headers = h
  end

  def query(h = {})
     h.map{ |k, v| URI.encode(k) + "=" + URI.encode(v.to_s) }.join("&")
  end

  def body(data = "")
    {:body => data}
  end
  def body_as_form(data = {})
    {:form => data}
  end
  def body_as_json(data = {})
    {:json => data}
  end

  def get(url, res_format="text", query="")
    url_obj = URI.parse(url)
    res = Net::HTTP.start(url_obj.host, url_obj.port) {|http|
      queries = []
      queries.push(query) unless query.empty?
      queries.push(url_obj.query) unless url_obj.query.nil?
      path_with_query =
        if queries.empty?
          url_obj.path
        else
          url_obj.path + "?" + queries.join("&")
        end
      request = Net::HTTP::Get.new(path_with_query)
      add_headers(request)
      http.request(request)
    }
    decorate_response(res, "GET", url, res_format)
  end

  def post(url, data, res_format)
    url_obj = URI.parse(url)
    res = Net::HTTP.start(url_obj.host, url_obj.port) {|http|
      request = Net::HTTP::Post.new(url_obj.path)
      setup(request, data)
      http.request(request)
    }
    decorate_response(res, "POST", url, res_format)
  end

  def put(url, data, res_format)
    url_obj = URI.parse(url)
    res = Net::HTTP.start(url_obj.host, url_obj.port) {|http|
      request = Net::HTTP::Put.new(url_obj.path)
      setup(request, data)
      http.request(request)
    }
    decorate_response(res, "PUT", url, res_format)
  end

  def delete(url, data, res_format)
    url_obj = URI.parse(url)
    res = Net::HTTP.start(url_obj.host, url_obj.port) {|http|
      request = Net::HTTP::DELETE.new(url_obj.path)
      setup(request, data)
      http.request(request)
    }
    decorate_response(res, "DELETE", url, res_format)
  end

private
  def setup(request, data)
    set_body(request, data)
    add_headers(request)
  end

  def add_headers(request)
    if @headers then @headers.each{|k, v| request.add_field k, v} end
  end

  def set_body(request, data)
    if data.include? :form
      set_form_data(request, data[:form])
    elsif data.include? :json
      request.body = JSON.generate(data[:json])
    else
      request.body = data[:body]
    end
  end

  def set_form_data(request, params, sep = '&')
    request.body = params.map {|k, v| encode_kvpair(k, v) }.flatten.join(sep)
    request.content_type = 'application/x-www-form-urlencoded'
  end

  def encode_kvpair(k, vs)
    Array(vs).map {|v| "#{URI::encode(k.to_s)}=#{URI::encode(v.to_s)}" }
  end

  def decorate_response(res, method, url, res_format)
    class << res
      attr_accessor :url, :res_format, :method
      def [](path)
        select(path)
      end
      def select(path, &block)
        result =
          if res_format && res_format == "xml"
            Nokogiri::XML(body).xpath(path).map{|x| x.text}
          elsif res_format && res_format == "html"
            Nokogiri::HTML(body).css(path).map{|x| x.text}
          elsif res_format && res_format == "json"
            JsonPath.on(body, path)
          end
        block.call(result) unless block.nil?
        result
      end
      def to_s
        method + " " + url
      end
    end
    res.url = url
    res.res_format = res_format
    res.method = method
    res
  end

  module_function :get, :post, :add_headers, :decorate_response
end

RSpec.configure do |c|
    c.include ItestHelpers
end

