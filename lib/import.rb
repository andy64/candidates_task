# encoding: utf-8
# frozen_string_literal: true

require_relative 'remote_connector'
require_relative 'transactions'
require_relative 'row'
require_relative 'csv_reader'
require_relative 'reporter'

module CSVOperations
  # main class to contain importing logic
  class Import
    attr_accessor :errors
    attr_reader :dtaus, :validation_only, :send_email, :import_retry_count

    def initialize(send_email = true, validation_only = false)
      @errors = []
      @dtaus = obtain_dtaus
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
        { success: ['data lost'], errors: [e.to_s] }
      end
      Reporter.new(local_file_path, result, @send_email).report_results
    end

    def import_file(file)
      FileUtils.mkdir_p PathManager.tmp_mraba
      rez = read_and_try_import(file)
      dtaus_add_datei if errors.empty? && !validation_only && dtaus
      errors.unshift(*rez[:validation_errors])
      { success: rez[:success_rows], errors: errors }
    end

    def repeat_row_import(row)
      @import_retry_count = 0
      5.times do
        @import_retry_count += 1
        if import_row(row)
          @import_retry_count.times { errors.pop } unless @import_retry_count == 1
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
      return unless transaction_pass(trans, row)
      return if transaction_with_errors?(trans)
      true
    end

    private

    def validate_row_import(row, validation_errors)
      return true if row.import_valid?
      validation_errors << "#{row.activity}:"\
          "#{Row::HEADERS[:umsatz_key]} #{row.umsatz_key} is not allowed"
      nil
    end

    def read_and_try_import(file)
      success_rows = []
      validation_errors = []
      CSVReader.read(file).each do |row|
        next if row.activity.blank? # skip row if activity_id is not defined
        next unless validate_row_import(row, validation_errors)
        next unless repeat_row_import(row)
        success_rows << row.activity
      end
      { success_rows: success_rows, validation_errors: validation_errors }
    end

    def transaction_with_errors?(trans)
      return false if trans.errors.blank?
      errors.push(*trans.errors)
      true
    end

    def transaction_pass(trans, row)
      begin
        trans.proc_transaction
      rescue => e
        errors << "#{row.activity}: #{e}"
        return
      end
      true
    end

    def dtaus_add_datei
      dtaus.add_datei(PathManager.mraba_csv_file) unless dtaus.is_empty?
    end

    def obtain_dtaus
      Mraba::Transaction.define_dtaus('RS', 8_888_888_888, 99_999_999, 'Credit collection')
    end
  end
end
