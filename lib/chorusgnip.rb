require 'net/http'
require 'net/https'
require "uri"
require 'csv'
require 'zlib'
require 'json'

class ChorusGnip

  attr_reader :url

  def self.from_stream(url, username, password)
    ChorusGnip.new(:url => url, :username => username, :password => password)
  end

  def initialize(input_values)
    @url= input_values[:url]
    @username= input_values[:username]
    @password= input_values[:password]

    @uri = URI.parse(@url)
    raise Exception, "URI not valid" unless @uri.host == 'historical.gnip.com'
    raise Exception, "URI not valid" unless @uri.scheme == 'https'
  end

  def create_connection
    http = Net::HTTP.new(@uri.host, @uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    http
  end

  def auth
    http = create_connection

    request = Net::HTTP::Head.new(@uri.request_uri)
    request.basic_auth(@username, @password)
    response = http.request(request)

    response.code == "200"
  end

  def fetch
    http = create_connection
    request = Net::HTTP::Get.new(@uri.request_uri)
    request.basic_auth(@username, @password)
    response = http.request(request)
    CSV.parse(response.body, { :col_sep => "\t", :quote_char => "'" }).map { |row| row.last }
  end

  def to_result
    resources_urls = fetch

    csv_string = CSV.generate(:force_quotes => true) do |csv|
      resources_urls.each do |value|
        list_of_hashes = GnipJson.new(:url => value).parse.each do |hsh|
          csv << [hsh['id'], hsh['body']]
        end
      end
    end

    GnipCsvResult.new(csv_string)


      # #'message_id'
      #       tweet_row << hsh['id']
      #       #'spam'
      #       tweet_row << nil
      #       #'created_at'
      #       tweet_row << hsh['postedTime']
      #       #'source'
      #       tweet_row << nil
      #       #'retweeted'
      #       tweet_row << hsh['retweetCount']
      #       #'favorited'
      #       tweet_row << nil
      #       #'truncated'
      #       tweet_row << nil
      #       #'in_reply_to_screen_name',
      #       tweet_row <<
      #       #'in_reply_to_user_id',
      #       #'author_id',
      #       #'author_name',
      #       #'author_screen_name',
      #       #'author_lang',
      #       #'author_url',
      #       #'author_description',
      #       #'author_listed_count',
      #       #'author_statuses_count',
      #       #'author_followers_count',
      #       #'author_friends_count',
      #       #'author_created_at',
      #       #'author_location',
      #       #'author_verified',
      #       #'message_url',
      #       #'message_text'
      #


      # Append it into a file
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
    gz.read.split("\n").reject{ |e| e.match(/^\s*$/) }[0...-1].inject([]) { |a, value| a << JSON.parse(value) }
  end
end

class GnipCsvResult
  attr_reader :column_names
  attr_reader :types
  attr_reader :contents

  def initialize(contents)
    @column_names = ['id', 'body']
    @types = ['text', 'text']
    @contents = contents
  end
end