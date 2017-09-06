# frozen_string_literal: true

require_relative 'spec_helper'
require_relative '../lib/row'
require_relative '../lib/transactions'

include Transactions

describe '.transaction' do
  it 'returns AccountTransfer' do
    row = Row.new(Row::HEADERS[:sender_blz] => '00000000',
                  Row::HEADERS[:receiver_blz] => '00000000')
    row.transaction.is_a?(AccountTransfer).should be true
  end

  it 'returns BankTransfer' do
    row = Row.new(Row::HEADERS[:sender_blz] => '00000000',
                  Row::HEADERS[:umsatz_key] => '10')
    row.transaction.is_a?(BankTransfer).should be true
  end

  it 'returns Lastschrift' do
    row = Row.new(Row::HEADERS[:receiver_blz] => '70022200',
                  Row::HEADERS[:umsatz_key] => '16')
    row.transaction.is_a?(Lastschrift).should be true
  end

  it 'returns false' do
    row = Row.new({})
    row.transaction.should be nil
  end

  it 'returns nil if exception' do
    row = Row.new(Row::HEADERS[:sender_blz] => '00000000')
    stub_const('Account', Class.new)
    allow(Account).to receive(:find_by_account_no).and_raise(StandardError)
    row.sender.should be nil
  end
end

describe '.import_subject' do
  it 'returns subject from row' do
    row = Row.new('DESC1' => 'Sub', 'DESC2' => 'ject')
    row.import_subject.should == 'Subject'
  end
end

describe '.import_valid?' do
  it 'validates row' do
  end
end
