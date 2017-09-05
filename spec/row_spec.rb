require 'spec_helper'
require_relative '../lib/row'
require_relative '../lib/transactions'

include Transactions

describe '.transaction_type(row)' do
  it 'returns AccountTransfer' do
    row = Row.new({Row::HEADERS[:sender_blz] => '00000000', Row::HEADERS[:receiver_blz] => '00000000'})
    row.transaction_type.kind_of?(AccountTransfer).should be true
  end

  it 'returns BankTransfer' do
    row = Row.new({Row::HEADERS[:sender_blz] => '00000000', Row::HEADERS[:umsatz_key] => '10'})
    row.transaction_type.kind_of?(BankTransfer).should be true
  end

  it 'returns Lastschrift' do
    row = Row.new({Row::HEADERS[:receiver_blz] => '70022200', Row::HEADERS[:umsatz_key] => '16'})
    row.transaction_type.kind_of?(Lastschrift).should be true
  end

  it 'returns false' do
    row = Row.new({})
    row.transaction_type.should be nil
  end
end

describe '.import_subject' do
  it 'returns subject from row' do
    row = Row.new({'DESC1' => 'Sub', 'DESC2' => 'ject'})
    row.import_subject.should == 'Subject'
  end
end

describe '.validate_import' do
  it 'validates row' do
  end
end
