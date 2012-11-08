require 'spec_helper'

require 'vcr'
require 'csv'

REAL_STREAM_URL=''
REAL_USERNAME=''
REAL_PASSWORD=''
REAL_GNIP_JSON_URL=''

VCR.configure do |c|
  c.cassette_library_dir = 'fixtures/vcr_cassettes'
  c.hook_into :fakeweb
end

describe 'Chorusgnip' do
  describe "create_connection" do
    let(:chorus_gnip) do
      ChorusGnip.new(
          :url => REAL_STREAM_URL,
          :username => REAL_USERNAME,
          :password => REAL_PASSWORD)
    end

    it "sets verify mode to VERIFY_PEER" do
      chorus_gnip.create_connection.verify_mode.should == OpenSSL::SSL::VERIFY_PEER
    end

    it "sets the ca_file to the correct certificate" do
      cert_path = File.expand_path('../../../lib/ssl-certs/cert.pem', __FILE__)
      chorus_gnip.create_connection.ca_file.should == cert_path
    end
  end

  context "validates a gnip url" do
    it "return true for valid credentials" do
      VCR.use_cassette('authorized_gnip') do
        g = ChorusGnip.new(
          :url => REAL_STREAM_URL,
          :username => REAL_USERNAME,
          :password => REAL_PASSWORD)

        g.url.should == REAL_STREAM_URL
        g.auth.should be_true
      end
    end

    it "return false for invalid credentials" do
      VCR.use_cassette('unauthorized_gnip') do
        g = ChorusGnip.new(
          :url => REAL_STREAM_URL,
          :username => REAL_USERNAME,
          :password => 'wrongpassword')

        g.auth.should be_false
      end
    end

    it "returns false for a plain HTTP url" do
        g = ChorusGnip.new(
        :url => 'http://historical.gnip.com/foo',
        :username => 'someemail',
        :password => 'wrongpassword')
        g.auth.should be_false

    end

    it "returns false for a url that cannot be parsed" do
        g = ChorusGnip.new(
        :url => nil,
        :username => 'someemail',
        :password => 'wrongpassword')
        g.auth.should be_false
    end

    it "makes sure that the URL is for a Gnip stream and not say https://google.com" do
      g = ChorusGnip.new(
      :url => 'https://www.google.com',
      :username => 'someemail',
      :password => 'wrongpassword')
      g.auth.should be_false
    end
  end

  context "producing a valid CSV file" do

    let(:g) {ChorusGnip.new(
        :url => REAL_STREAM_URL,
        :username => REAL_USERNAME,
        :password => REAL_PASSWORD) }

    before do
      mock(g).to_result_in_batches(anything) {GnipCsvResult.new("")}
    end
    it "gets all the historical data" do
      VCR.use_cassette('successful_get') do

        results = g.fetch
        results.length.should_not == 0
        results.each { |url| url.should include('https:') }

        result = g.to_result

      end
    end
  end
  context "producing an array of CSV files" do
    it "gets all the historical data" do
      VCR.use_cassette('successful_get') do
        g = ChorusGnip.new(
            :url => REAL_STREAM_URL,
            :username => REAL_USERNAME,
            :password => REAL_PASSWORD)

        result_urls = g.fetch
        result_urls.length.should_not == 0
        result_urls.each { |url| url.should include('https:') }

        results = g.to_result_in_batches(result_urls)
        results.class.should == GnipCsvResult

        results.column_names.should == ['id', 'body', 'link', 'posted_time', 'actor_id', 'actor_link',
                                           'actor_display_name', 'actor_posted_time', 'actor_summary',
                                           'actor_friends_count', 'actor_followers_count', 'actor_statuses_count',
                                           'retweet_count']
        results.types.should == ['text', 'text', 'text', 'timestamp', 'text', 'text',
                                    'text', 'timestamp', 'text',
                                    'integer', 'integer', 'integer',
                                    'integer']

        csv = CSV.parse(results.contents)
        f = File.open('result.csv', 'w')
        f.puts results.contents
        f.close

        csv.length.should == 42
        csv.each do |row|
          row.length.should == results.column_names.length
          row[results.column_names.index('posted_time')].should_not be_empty
          row[results.column_names.index('actor_posted_time')].should_not be_empty
        end
      end
    end
  end

  it "operations on a single JSON file" do
    VCR.use_cassette('3_activity_json') do
      c = GnipJson.new(:url => REAL_GNIP_JSON_URL)
      activity_list = c.parse
      activity_list.length.should == 3
      activity_list.each { |hash| hash['id'].should_not == nil }
    end
  end
end