# frozen_string_literal: true

require_relative 'spec_helper'
require 'net/ssh'
require 'net/sftp'
require_relative '../lib/remote_connector'

# these tests require SFTP local server configured to maintain the 'spec/fixtures/sftp_server_dir'
# checking the RemoteConnector class methods to operate files via Net::SFTP
# tests commented because will fail without proper pre-configurations

describe 'Remote connector' do
  # describe '.download files using local sftp' do
  #   before(:each) do
  #     @rc = RemoteConnector.new(true)
  #   end
  #
  #   it 'gets remote files to download' do
  #     @rc.send(:within_session) do |sftp|
  #       @rc.send(:remote_files_path_list, sftp)
  #          .should eq ['csv_exporter.csv', 'fakefile.csv.start']
  #     end
  #   end
  #
  #   it 'downloads files to local path' do
  #     tmpdir = 'temp'
  #     FileUtils.rm_rf tmpdir
  #     FileUtils.mkpath tmpdir
  #     @rc = RemoteConnector.new(true)
  #     allow(@rc).to receive(:local_download_path).and_return tmpdir
  #     allow(@rc).to receive(:remove_start_remote_files).and_return true
  #     rez = @rc.download_files
  #     rez.each do |file|
  #       File.exist?(file).should be true
  #     end
  #     rez.size.should eq 2
  #     Dir.entries(tmpdir).reject { |x| %w[. ..].include?(x) }.size.should eq 2
  #     FileUtils.rm_rf tmpdir
  #   end
  #
  #   it 'removes .start files from remote dir after download' do
  #   end
  #
  #   it 'uploads file to remote dir' do
  #   end
  # end
end
