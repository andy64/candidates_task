# frozen_string_literal: true

require 'bundler/setup'
require 'active_support/all'
require 'rspec'
require_relative '../lib/path_manager'

include CSVOperations
include PathManager

RSpec.configure do |config|
  config.expect_with(:rspec) { |c| c.syntax = :should }
end
