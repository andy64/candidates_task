# encoding: utf-8
require 'spec_helper'
require_relative '../lib/csv_exporter'

# Fakes for outside objects
class Account
  def self.find_by_account_no(*)
  end
end

module Mraba
  class Transaction
    def self.define_dtaus(*args)
      new
    end

    def valid_sender?(*)
    end

    def add_buchung(*)
    end

    def add_datei(*)
    end
  end
end

module BackendMailer
  extend self

  def send_import_feedback(*args)
  end
end

describe CsvExporter do

  describe '.transfer_and_import(send_email = true)' do
    before(:all) do
      download_folder = "#{Rails.root}/private/data/download"
      FileUtils.mkdir_p download_folder
      FileUtils.cp "#{Rails.root}/spec/fixtures/csv_exporter.csv", "#{download_folder}/mraba.csv"
    end
    after(:all) do
      FileUtils.rm_r "#{Rails.root}/private"
    end

    before(:each) do
      entries = ['mraba.csv', 'mraba.csv.start', 'blubb.csv']
      sftp_mock = double('sftp')
      Net::SFTP.stub(:start).and_yield(sftp_mock)
      sftp_mock.stub_chain(:dir, :entries, :map).and_return(entries)
      sftp_mock.stub(:download!).with('/data/files/csv/mraba.csv', "#{Rails.root}/private/data/download/mraba.csv")
      sftp_mock.stub(:remove!).with('/data/files/csv/mraba.csv.start')
      sftp_mock.stub(:upload!).with("#{Rails.root}/private/data/upload/mraba.csv", '/data/files/batch_processed/mraba.csv').once
    end

    it 'fails transfers and imports mraba csv  ' do
      CsvExporter.should_receive(:upload_error_file).once.and_call_original
      File.should_receive(:open).with("#{Rails.root}/private/data/download/mraba.csv",
                                      {:universal_newline=>false, :col_sep=> ';', :headers=>true, :skip_blanks=>true}).once.and_call_original
      File.should_receive(:open).with("#{Rails.root}/private/data/upload/mraba.csv", 'w').once.and_call_original
      CsvExporter.transfer_and_import
    end

    it 'fails transfers and imports mraba csv' do
      file_to_upload = double('file to upload')
      File.should_receive(:open).with("#{Rails.root}/private/data/download/mraba.csv",  {:universal_newline=>false, :col_sep=> ';', :headers=>true, :skip_blanks=>true}).once.and_call_original

      File.should_receive(:open).with("#{Rails.root}/private/data/upload/mraba.csv", 'w').once.and_yield(file_to_upload)
      file_to_upload.should_receive(:write).once
      CsvExporter.should_receive(:upload_error_file).once.and_call_original
      BackendMailer.should_receive(:send_import_feedback).with('Import CSV failed', "Import of the file mraba.csv failed with errors:\nImported:  Errors: 01: UMSATZ_KEY 06 is not allowed; 01: Transaction type not found")

      CsvExporter.transfer_and_import
    end

    it 'transfers and imports mraba csv' do
      data = {
        'DEPOT_ACTIVITY_ID' => '',
        'AMOUNT' => '5',
        'UMSATZ_KEY' => '10',
        'ENTRY_DATE' => Time.now.strftime('%Y%m%d'),
        'KONTONUMMER' => '000000001',
        'RECEIVER_BLZ' => '00000000',
        'RECEIVER_KONTO' => '000000002',
        'RECEIVER_NAME' => 'Mustermann',
        'SENDER_BLZ' => '00000000',
        'SENDER_KONTO' => '000000003',
        'SENDER_NAME' => 'Mustermann',
        'DESC1' => 'Geld senden'
      }

      CSV.stub_chain(:read, :map).and_return [ ['123', data ] ]

      BackendMailer.should_receive(:send_import_feedback)
      CsvExporter.transfer_and_import.should be_nil
    end
  end


  describe '.import(file, validation_only = false)' do
    it 'handles exception during import' do
      CsvExporter.stub(:import_file).and_raise(RuntimeError)
      CsvExporter.import(nil).should == 'Imported: data lost Errors: RuntimeError'
    end
  end


  describe '.import_file_row_with_error_handling(row, validation_only = false)' do
    before(:each) do
      @errors = []
      @dtaus = double
    end

    it 'successful import' do
      row = {
        'RECEIVER_BLZ' => '00000000',
        'SENDER_BLZ' => '00000000',
        'ACTIVITY_ID' => '1'
      }

      CsvExporter.stub(:add_account_transfer).and_return(true)
      CsvExporter.import_file_row_with_error_handling(row, false, @errors, @dtaus).should == [@errors,@dtaus]
      CsvExporter.import_retry_count.should == 1
    end

    it 'handles exception in row' do
      row = {
        'RECEIVER_BLZ' => '00000000',
        'SENDER_BLZ' => '00000000',
        'ACTIVITY_ID' => '1'
      }

      CsvExporter.stub(:add_account_transfer).and_raise(RuntimeError)
      CsvExporter.import_file_row_with_error_handling(row, false, @errors, @dtaus)[0].should == ['1: RuntimeError']
      CsvExporter.import_retry_count.should == 1
    end
  end




  describe '.import_subject(row)' do
    before(:each) do
      @row = {'DESC1' => 'Sub', 'DESC2' => 'ject'}
    end

    it 'returns subject from row' do
      CsvExporter.import_subject(@row).should == 'Subject'
    end
  end


end
