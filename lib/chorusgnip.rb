require 'net/http'
require 'net/https'
require "uri"
require 'csv'
require 'zlib'
require 'json'

class ChorusGnip

  attr_reader :url

  def self.column_names
    ['id', 'body', 'link', 'posted_time', 'actor_id', 'actor_link',
     'actor_display_name', 'actor_posted_time', 'actor_summary',
     'actor_friends_count', 'actor_followers_count', 'actor_statuses_count',
     'retweet_count']
  end

  def self.column_types
    ['text', 'text', 'text', 'timestamp', 'text', 'text',
     'text', 'timestamp', 'text',
     'integer', 'integer', 'integer',
     'integer']
  end

  def self.from_stream(url, username, password)
    ChorusGnip.new(:url => url, :username => username, :password => password)
  end

  def initialize(input_values)
    @url= input_values[:url]
    @username= input_values[:username]
    @password= input_values[:password]
  end

  def uri
    @uri ||= URI.parse(@url)
  end

  def create_connection
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_PEER
    http.ca_file = File.expand_path('../ssl-certs/cert.pem', __FILE__)
    http
  end

  def auth
    raise Exception, "URI not valid" unless uri.host == 'historical.gnip.com'
    raise Exception, "URI not valid" unless uri.scheme == 'https'

    http = create_connection

    request = Net::HTTP::Head.new(uri.request_uri)
    request.basic_auth(@username, @password)
    response = http.request(request)

    response.code == "200"
  rescue Exception => e
    false
  end

  def fetch
    http = create_connection
    request = Net::HTTP::Get.new(uri.request_uri)
    request.basic_auth(@username, @password)
    response = http.request(request)
    CSV.parse(response.body, {:col_sep => "\t", :quote_char => "'"}).map { |row| row.last }
  end

  def to_result
    resource_urls = fetch
    to_result_in_batches(resource_urls)
  end

  def to_result_in_batches(resource_urls)
    csv_string = CSV.generate(:force_quotes => true) do |csv|
      resource_urls.each do |value|
        GnipJson.new(:url => value).parse.each do |hsh|
          csv << [hsh['id'], hsh['body'], hsh['link'], hsh['postedTime'], hsh['actor']['id'], hsh['actor']['link'],
                  hsh['actor']['displayName'], hsh['actor']['postedTime'], hsh['actor']['summary'],
                  hsh['actor']['friendsCount'], hsh['actor']['followersCount'], hsh['actor']['statusesCount'],
                  hsh['retweetCount']]
        end
      end
    end
    GnipCsvResult.new(csv_string)
  end
end

class GnipJson
  attr_reader :url

  def initialize(options)
    @url = options[:url]
  end

  def parse
    uri = URI.parse(url)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    request = Net::HTTP::Get.new(uri.request_uri)
    response = http.request(request)
    gz = Zlib::GzipReader.new(StringIO.new(response.body))
    gz.read.split("\n").reject { |e| e.match(/^\s*$/) }[0...-1].inject([]) { |a, value| a << JSON.parse(value) }
  end
end

class GnipCsvResult
  attr_reader :column_names
  attr_reader :types
  attr_reader :contents

  def initialize(contents)
    @column_names = ChorusGnip.column_names
    @types = ChorusGnip.column_types
    @contents = contents
  end
end