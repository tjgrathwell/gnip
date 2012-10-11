require_relative '../lib/chorusgnip'

require 'vcr'

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
      VCR.use_cassette('plain_http_gnip') do
        g = ChorusGnip.new(
          :url => 'http://historical.gnip.com/something',
          :username => 'someemail',
          :password => 'wrongpassword')

        g.auth.should be_false
      end
    end

    it "makes sure that the URL is for a Gnip stream and not say https://google.com" do
      VCR.use_cassette('not_a_gnip_stream') do
        g = ChorusGnip.new(
          :url => 'https://www.google.com',
          :username => 'something',
          :password => 'wrongpassword')

        g.auth.should be_false
      end
    end
  end
end