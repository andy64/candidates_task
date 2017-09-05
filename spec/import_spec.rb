require 'spec_helper'
require_relative '../lib/import'

include Transactions

describe 'Import' do
  before(:each) do
    @row = {Row::HEADERS[:activity] => 1,
            Row::HEADERS[:amount] => 10,
            Row::HEADERS[:umsatz_key] => '10',
            Row::HEADERS[:entry_date] => Date.today,
            Row::HEADERS[:desc1] => 'Subject',
            Row::HEADERS[:sender_konto] => '000000001',
            Row::HEADERS[:receiver_konto] => '000000002'}
    stub_const('Mraba::Transaction', Class.new)
    allow(Mraba::Transaction).to receive(:define_dtaus).and_return(double('dtaus', is_empty?: false, add_datei:true))
    @import = Import.new
  end


  describe '.import_row' do
    it 'import row valid case' do
      allow_any_instance_of(Row).to receive(:transaction).and_return(Transaction.new(@row))
      allow_any_instance_of(Transaction).to receive(:proc_transaction).and_return(true)
      rez = @import.import_row(Row.new(@row))
      rez.should_not be nil
      @import.errors.size == 0
    end

    context 'without success' do
      it 'import row undefined transaction' do
        rez = @import.import_row(Row.new(@row))
        rez.should be nil
        @import.errors.size == 1
        @import.errors.first == '1: Transaction type not found'
      end

      it 'import row with proc_transaction exception' do
        allow_any_instance_of(Row).to receive(:transaction).and_return(Transaction.new(@row))
        error_text = 'ERROR: text to check'
        allow_any_instance_of(Transaction).to receive(:proc_transaction).and_raise(RuntimeError, error_text)
        rez = @import.import_row(Row.new(@row))
        rez.should be nil
        @import.errors.size == 1
        @import.errors.first.should == "#{@row[Row::HEADERS[:activity]]}: #{error_text}"
      end

      it 'import row with transaction error' do
        allow_any_instance_of(Row).to receive(:transaction).and_return(Transaction.new(@row))
        error_text = 'ERROR: text to check'
        allow_any_instance_of(Transaction).to receive(:proc_transaction).and_return nil
        allow_any_instance_of(Transaction).to receive(:errors).and_return [error_text]
        rez = @import.import_row(Row.new(@row))
        rez.should be nil
        @import.errors.size == 1
        @import.errors.first.should == error_text
      end
    end


  end

  describe '.repeat_row_import' do
    it 'changes counter and break after overcount' do
      @import.repeat_row_import(Row.new(@row))
      @import.import_retry_count.should == 5
    end
    it 'doesn\'t log error if last attempt passed' do
      allow(@import).to receive(:import_row).and_return{
        @import.errors.push('error text')
        @import.import_retry_count==3
      }
      @import.repeat_row_import(Row.new(@row))
      @import.errors.blank?.should be true
    end
  end

  describe '.import_file' do
    before(:each) do
      FileUtils.rm_rf 'temp'
      allow(PathManager).to receive(:tmp_mraba).and_return 'temp'
      stub_const('CSVOperations::Row::Account', Class.new)
      allow(CSVOperations::Row::Account)
          .to receive(:find_by_account_no)
                  .and_return double('account', :build_transfer=>double('bank_transfer', save!: true, valid?: true))
    end

    it 'imports the file' do
      rez = @import.import_file "spec/fixtures/sftp_server_dir/#{remote_csv_path}/csv_exporter.csv"
      rez[:success].first.should == '07'
      rez[:errors].size.should == 10
    end
  end


    it 'imports empty file' do
      rez = @import.import_file "spec/fixtures/csv_empty.csv"
      rez[:success].blank?.should be true
      rez[:errors].blank?.should be true
    end

end
