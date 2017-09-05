require 'spec_helper'
require_relative '../lib/transactions'

include Transactions

describe 'Transactions' do
  describe '.get_sender' do
    before(:each) do
      @account = double
      @row = Row.new({Row::HEADERS[:sender_konto] => '000000001', Row::HEADERS[:activity] => 12})
      @row.stub(:sender) { @account }
      @trans = Transaction.new(@row)
    end

    it 'gets sender from row' do
      @trans.get_sender.should == @account
    end

    it 'fails to get sender from row' do
      @row.stub(:sender) { nil }
      @trans.get_sender.should be nil
      @trans.errors.size.should == 1
      @trans.errors.first.should == '12: Account 000000001 not found'
    end
  end

  context 'AccountTransfer' do
    before(:each) do
      def prepare_instance_vars
        @account = double :account_no => '000000001'
        @account_transfer = double('date=': nil, 'skip_mobile_tan=': nil, valid?: nil,
                                   errors: double(full_messages: []), save!: true)
        stub_const('Account', Class.new)
        Account.stub(:find_by_account_no).and_return @account
        row = {Row::HEADERS[:amount] => 10,
               Row::HEADERS[:entry_date] => Date.today,
               Row::HEADERS[:desc1] => 'Subject',
               Row::HEADERS[:sender_konto] => '000000001',
               Row::HEADERS[:receiver_konto] => '000000002'}
        yield(row) if block_given?
        @trans = AccountTransfer.new(Row.new(row))
        @account.stub_chain(:credit_account_transfers, :build).and_return @account_transfer
      end
    end

    describe '.proc_transaction, DEPOT_ACTIVITY_ID is blank' do

      it 'adds account_transfer' do
        prepare_instance_vars
        @trans.validation_only = false
        @account_transfer.stub valid?: true
        @trans.proc_transaction.should be true
        @trans.errors.size.should == 0
      end

      it 'fails to add a account_transfer (missing attribute)' do
        prepare_instance_vars { |row| row[Row::HEADERS[:amount]] = nil }
        @trans.validation_only = false
        @trans.proc_transaction.should be false
        @trans.errors.size.should == 1
      end

      it 'fails to add a account_transfer (missing attribute, validation only)' do
        prepare_instance_vars { |row| row[Row::HEADERS[:amount]] = nil }
        @trans.validation_only = true
        @trans.proc_transaction.should be false
        @trans.errors.size.should == 1
      end

      it 'returns error if sender not found' do
        prepare_instance_vars do |h|
          h[Row::HEADERS[:activity]] = 12
          stub_const('Account', Class.new)
          Account.stub(:find_by_account_no).and_return nil
        end
        @trans.proc_transaction.should be false
        @trans.errors.size.should == 1
        @trans.errors.first.should == '12: Account 000000001 not found'
      end

    end

    describe '.proc_transaction, DEPOT_ACTIVITY_ID is not blank' do

      it 'finds and validates account_transfer' do
        prepare_instance_vars do |row|
          @account_transfer.stub(id: 1, state: 'pending', 'subject=': nil, valid?: true, complete_transfer!: true)
          row[Row::HEADERS[:depot_activity_id]] = @account_transfer.id
        end
        @account.stub_chain(:credit_account_transfers, :find_by_id).and_return @account_transfer
        @account_transfer.should_receive :complete_transfer!
        @trans.proc_transaction.should be true
        @trans.errors.size.should == 0
      end

      it 'fails to find account transfer' do
        prepare_instance_vars do |row|
          row[Row::HEADERS[:depot_activity_id]] = 12345
        end
        @account.stub_chain :credit_account_transfers, find_by_id: nil
        @trans.proc_transaction.should be nil
        @trans.errors.size.should == 1
        @trans.errors.first.should == ': AccountTransfer not found'
      end

      it 'finds account transfer, but is not in pending state' do
        prepare_instance_vars do |row|
          @account_transfer.stub id: 1, state: 'initialized'
          row[Row::HEADERS[:depot_activity_id]] = @account_transfer.id
        end
        @account.stub_chain(:credit_account_transfers, :find_by_id).and_return @account_transfer
        @trans.proc_transaction.should be nil
        @trans.errors.size.should == 1
        @trans.errors.first.should == ': AccountTransfer state expected \'pending\' but was \'initialized\''
      end
    end
  end

  context 'BankTransfer' do
    describe '.proc_transaction' do

      before(:each) do
        row = {Row::HEADERS[:amount] => 10,
               Row::HEADERS[:receiver_name] => 'Bob Baumeiter',
               Row::HEADERS[:receiver_blz] => '2222222',
               Row::HEADERS[:entry_date] => Date.today,
               Row::HEADERS[:desc1] => 'Subject',
               Row::HEADERS[:sender_konto] => '000000001',
               Row::HEADERS[:receiver_konto] => '000000002'}
        @trans = BankTransfer.new(Row.new(row))
        bank_transfer = double :valid? => true, :save! => true
        @account = double :build_transfer => bank_transfer
        stub_const('Account', Class.new)
      end

      it 'adds bank transfer' do
        Account.stub(:find_by_account_no).with('000000001').and_return @account
        @trans.proc_transaction.should be true
      end

      it 'fails to add bank transfer' do
        Account.stub(:find_by_account_no).with('000000001').and_return nil
        @trans.proc_transaction.should be false
        @trans.errors.first.should == ': Account 000000001 not found'
        @trans.errors.size.should == 1
      end
    end
  end

  context 'Lastschrift' do
    describe '.proc_transaction' do
      before(:each) do
        row = {Row::HEADERS[:activity] => '1',
               Row::HEADERS[:amount] => '10',
               Row::HEADERS[:receiver_name] => 'Bob Baumeiter',
               Row::HEADERS[:receiver_blz] => '70022200',
               Row::HEADERS[:desc1] => 'Subject',
               Row::HEADERS[:sender_konto] => '0101881952',
               Row::HEADERS[:sender_blz] => '30020900',
               Row::HEADERS[:sender_name] => 'Max Müstermänn',
               Row::HEADERS[:receiver_konto] => 'NO2'}
        @trans = Lastschrift.new(Row.new(row))
        @dtaus = double
      end

      it 'adds dta row' do
        @dtaus.stub(:valid_sender?).with('0101881952', '30020900').and_return true
        @dtaus.should_receive(:add_buchung).with('0101881952', '30020900', 'Max Mustermann', 10, 'Subject').once
        @trans.dtaus = @dtaus
        @trans.proc_transaction
      end

      it 'fails to adds dta row' do
        @dtaus.stub(:valid_sender?).with('0101881952', '30020900').and_return false
        @dtaus.should_not_receive(:add_buchung)
        @trans.dtaus = @dtaus
        @trans.proc_transaction.should be false
        @trans.errors.first.should == '1: BLZ/Konto not valid, csv fiile not written'
        @trans.errors.size.should == 1
      end

    end
  end


end
