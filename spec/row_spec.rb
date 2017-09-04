require 'spec_helper'
require_relative '../lib/row'


describe '.transaction_type(row)' do
  it "returns 'AccountTransfer'" do
    row = { 'SENDER_BLZ' => '00000000', 'RECEIVER_BLZ' => '00000000' }
    CsvExporter.transaction_type(row).should == 'AccountTransfer'
  end

  it "returns 'BankTransfer'" do
    row = { 'SENDER_BLZ' => '00000000', 'UMSATZ_KEY' => '10' }
    CsvExporter.transaction_type(row).should == 'BankTransfer'
  end

  it "returns 'Lastschrift'" do
    row = { 'RECEIVER_BLZ' => '70022200', 'UMSATZ_KEY' => '16' }
    CsvExporter.transaction_type(row).should == 'Lastschrift'
  end

  it "returns 'false'" do
    row = { }
    CsvExporter.transaction_type(row).should be false
  end
end

describe 'import subject' do

end

