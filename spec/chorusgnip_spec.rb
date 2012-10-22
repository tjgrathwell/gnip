require_relative '../lib/chorusgnip'

require 'vcr'
require 'csv'

REAL_STREAM_URL=''
REAL_USERNAME=''
REAL_PASSWORD=''


VCR.configure do |c|
  c.cassette_library_dir = 'fixtures/vcr_cassettes'
  c.hook_into :fakeweb
end

describe 'Chorusgnip' do
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
    it "gets all the historical data" do
      VCR.use_cassette('successful_get') do
        g = ChorusGnip.new(
          :url => REAL_STREAM_URL,
          :username => REAL_USERNAME,
          :password => REAL_PASSWORD)

        results = g.fetch
        results.length.should_not == 0
        results.each { |url| url.should include('https:') }

        result = g.to_result
        result.class.should == GnipCsvResult

        result.column_names.should == ['id', 'body', 'link', 'posted_time', 'actor_id', 'actor_link',
                                       'actor_display_name', 'actor_posted_time', 'actor_summary',
                                       'actor_friends_count', 'actor_followers_count', 'actor_statuses_count',
                                       'retweet_count']
        result.types.should == ['text', 'text', 'text', 'timestamp', 'text', 'text',
                                'text', 'timestamp', 'text',
                                'integer', 'integer', 'integer',
                                'integer']

        csv = CSV.parse(result.contents)
        f = File.open('result.csv', 'w')
        f.puts result.contents
        f.close

        csv.length.should == 41401
        csv.each do |row|
          row.length.should == result.column_names.length
          row[result.column_names.index('posted_time')].should_not be_empty
          row[result.column_names.index('actor_posted_time')].should_not be_empty
        end
      end
    end
  end

  context "operations on a single JSON file" do
    VCR.use_cassette('3_activity_json') do
      c = GnipJson.new(:url => REAL_GNIP_JSON_URL)
      activity_list = c.parse
      activity_list.length.should == 3
      activity_list.each { |hash| hash['id'].should_not == nil }
    end
  end
end