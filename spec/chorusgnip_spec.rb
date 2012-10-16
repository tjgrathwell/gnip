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
      expect do
        g = ChorusGnip.new(
        :url => 'http://historical.gnip.com/foo',
        :username => 'someemail',
        :password => 'wrongpassword')
      end.to raise_exception
    end

    it "returns false for a url that cannot be parsed" do
        expect do
          g = ChorusGnip.new(
          :url => nil,
          :username => 'someemail',
          :password => 'wrongpassword')
        end.to raise_exception
    end

    it "makes sure that the URL is for a Gnip stream and not say https://google.com" do
      expect do
        g = ChorusGnip.new(
        :url => 'https://www.google.com',
        :username => 'someemail',
        :password => 'wrongpassword')
      end.to raise_exception
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
                                       'retweet_count', 'gnip_klout_score']
        result.types.should == ['text', 'text', 'text', 'timestamp', 'text', 'text',
                                'text', 'timestamp', 'text',
                                'integer', 'integer', 'integer',
                                'integer', 'integer']

        csv = CSV.parse(result.contents)
        csv.length.should == 42
        csv.each do |row|
          row.length.should == result.column_names.length
          row[result.column_names.index('posted_time')].should_not be_empty
          row[result.column_names.index('actor_posted_time')].should_not be_empty
        end

        # result.column_names.should == [
        #   'message_id', 'spam', 'created_at', 'source', 'retweeted', 'favorited', 'truncated', 'in_reply_to_screen_name',
        #   'in_reply_to_user_id', 'author_id', 'author_name', 'author_screen_name', 'author_lang', 'author_url', 'author_description',
        #   'author_listed_count', 'author_statuses_count', 'author_followers_count', 'author_friends_count', 'author_created_at',
        #   'author_location', 'author_verified', 'message_url', 'message_text'
        # ]
        # result.types.should == [
        #   'bigint', 'boolean', 'timestamp without time zone', 'text', 'boolean', 'boolean', 'boolean', 'text', 'bigint',
        #   'bigint', 'text', 'text', 'text', 'text', 'text', 'integer', 'integer', 'integer', 'integer', 'timestamp without time zone', 'text', 'boolean', 'text', 'text'
        #   ]
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