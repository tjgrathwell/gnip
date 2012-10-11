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
  end
end