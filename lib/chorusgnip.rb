require 'net/https'
require "uri"

class ChorusGnip

  attr_reader :url

  def initialize(input_values)
    @url= input_values[:url]
    @username= input_values[:username]
    @password= input_values[:password]
  end

  def auth
    begin
      uri = URI.parse(@url)
    rescue Exception => e
      return false
    end

    return false unless uri.host == 'historical.gnip.com'
    return false unless uri.scheme == 'https'

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    request = Net::HTTP::Head.new(uri.request_uri)
    request.basic_auth(@username, @password)
    response = http.request(request)

    response.code == "200"
  end
end
