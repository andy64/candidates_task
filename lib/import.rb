# encoding: utf-8
require_relative 'remote_connector'
require_relative 'transactions'
require_relative 'row'
require_relative 'csv_reader'
require_relative 'reporter'

module CSVOperations

  class Import
    attr_accessor :errors
    attr_reader :dtaus, :validation_only, :send_email, :import_retry_count

    def initialize(send_email=true, validation_only=false)
      @errors = []
      @dtaus = get_dtaus
      @validation_only = validation_only
      @send_email = send_email
      @import_retry_count = 0
    end

    def do_transfer_and_import
      FileUtils.mkdir_p(local_download_path)
      local_file_paths = RemoteConnector.new.download_files

      local_file_paths.each do |local_file_path|
        import(local_file_path, send_email)
      end
    end

    def import(local_file_path)
      result = begin
        import_file(local_file_path)
      rescue => e
        {success: ['data lost'], errors: [e.to_s] }
      end
      Reporter.new(local_file_path, result, @send_email).report_results
    end

    def import_file(file)
      success_rows = []
      validation_errors = []
      FileUtils.mkdir_p PathManager.tmp_mraba
      CSVReader.read(file).each do |row|
        next if row.activity.blank? #skip row if activity_id is not defined
        unless row.is_import_valid?
          validation_errors << "#{row.activity}: #{Row::HEADERS[:umsatz_key]} #{row.umsatz_key} is not allowed"
          next
        end
        next unless repeat_row_import(row)
        success_rows << row.activity
      end
      if errors.empty? and !validation_only and dtaus
        dtaus.add_datei(PathManager.mraba_csv_file) unless dtaus.is_empty?
      end
      errors.unshift *validation_errors
      {success: success_rows, errors: errors}
    end

    def repeat_row_import(row)
      @import_retry_count = 0
      5.times do
        @import_retry_count += 1
        if import_row(row)
          @import_retry_count.times{ errors.pop } unless @import_retry_count==1
          return true
        end
      end
      nil
    end

    def import_row(row)
      trans = row.transaction
      unless trans
        errors << "#{row.activity}: Transaction type not found"
        return
      end
      trans.validation_only = validation_only
      trans.dtaus = dtaus
      begin
        trans.proc_transaction
      rescue => e
        errors << "#{row.activity}: #{e.to_s}"
        return
      end
      unless trans.errors.size==0
        errors.push *trans.errors
        return
      end
      true
    end

    private
    def get_dtaus
      Mraba::Transaction.define_dtaus('RS', 8888888888, 99999999, 'Credit collection')
    end

  end
end
