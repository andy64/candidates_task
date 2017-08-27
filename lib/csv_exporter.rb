# encoding: utf-8

require 'import'

class CsvExporter
  def self.transfer_and_import(send_email = true)
    im = CSVOperations::Import.new(false)
    im.do_transfer_and_import(send_email)
  end
end


CsvExporter.transfer_and_import