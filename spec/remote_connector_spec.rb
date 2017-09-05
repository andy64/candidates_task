require 'spec_helper'
require 'net/ssh'
require 'net/sftp'
require_relative '../lib/remote_connector'

include CSVOperations

describe '.download files' do
  it 'gets remote files to download' do

    rc = RemoteConnector.new
    sftp = double('sftp', :opendir! => true, :close! => true)
    dir_obj = Net::SFTP::Operations::Dir.new(sftp)
    sftp.stub(dir: dir_obj)
    allow_any_instance_of(RemoteConnector).to receive(:remote_csv_path).and_return Dir.getwd + '/spec/fixtures'
    rc.send(:remote_files_path_list, sftp).should == ['csv_exporter.csv, fakefile.csv.start']
  end

  it 'downloads files to local path' do
    FileUtils.mkpath 'temp'
    rc = RemoteConnector.new
    rc.stub(:remote_files_path_list).and_return('fixtures/csv_exporter.csv')
    rc.download_files
  end

  #
  it 'temp test' do
    Net::SFTP.start('127.0.0.1', 'andy64', :port => 22, :password=>'831149', :keys => ['C:\Users\MyPC\Documents\privatekey.rsa'] ) do |sftp|
      p sftp
    end
  end


end