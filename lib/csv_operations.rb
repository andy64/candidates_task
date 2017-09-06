# encoding: utf-8

require_relative 'import'

class CsvExporter
  def self.transfer_and_import(send_email = true)
    im = CSVOperations::Import.new(send_email: send_email)
    im.do_transfer_and_import
  end
end
