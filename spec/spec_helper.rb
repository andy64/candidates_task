require 'bundler/setup'
require 'active_support/all'
require 'rspec'
require_relative '../lib/path_manager'

include CSVOperations
include PathManager

RSpec.configure do |config|
end

