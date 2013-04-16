require File.dirname(__FILE__) + "/../lib/chorusgnip"

require 'vcr'
require 'csv'

RSpec.configure do |config|
  config.mock_with :rr
end

VCR.configure do |c|
  c.cassette_library_dir = 'fixtures/vcr_cassettes'
  c.hook_into :fakeweb
end
