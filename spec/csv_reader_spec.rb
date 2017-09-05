require 'spec_helper'
require_relative '../lib/csv_reader'
require_relative '../lib/row'


describe 'CSV reader' do
  it 'reads csv file' do
    rez = CSVReader.read "spec/fixtures/sftp_server_dir/#{remote_csv_path}/csv_exporter.csv"
    rez.size.should == 5
    rez.last.is_a?(Row).should be true
    rez.each do |row|
      actual = row.keys
      Row::HEADERS.values.each do |header|
        actual.include?(header).should be true
      end
    end
  end

  it 'reads empty content csv' do
    rez = CSVReader.read 'spec/fixtures/csv_empty.csv'
    rez.size.should == 0
  end

  it 'reads absolute empty csv' do
    rez = CSVReader.read 'spec/fixtures/absolute_empty.csv'
    rez.size.should == 0
  end

end
