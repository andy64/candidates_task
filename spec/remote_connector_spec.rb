require 'spec_helper'
require 'net/ssh'
require 'net/sftp'
require_relative '../lib/remote_connector'

describe '.download files' do
  before(:each) do
    @rc = RemoteConnector.new(use_test_creds=true)
  end

  it 'gets remote files to download' do
    @rc.send(:within_session) do |sftp|
      @rc.send(:remote_files_path_list, sftp).should == ['csv_exporter.csv', 'fakefile.csv.start']
    end
  end

  it 'downloads files to local path' do
    tmpdir = 'temp'
    FileUtils.rm_rf tmpdir
    FileUtils.mkpath tmpdir
    @rc = RemoteConnector.new(use_test_creds=true)
    allow(@rc).to receive(:local_download_path).and_return tmpdir
    allow(@rc).to receive(:remove_start_remote_files).and_return true
    rez = @rc.download_files
    rez.each do |file|
      File.exists?(file).should be true
    end
    rez.size.should == 2
    Dir.entries(tmpdir).reject{|x| x=='.' or x=='..'}.size.should == 2
    FileUtils.rm_rf tmpdir
  end

  it 'removes .start files from remote dir after download' do

  end

  it 'uploads file to remote dir' do

  end

end