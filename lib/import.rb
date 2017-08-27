# encoding: utf-8

require 'remote_connector'
require 'transactions'
require 'row'
require 'csv_reader'

module CSVOperations


  class Import
    attr_accessor :import_retry_count
    attr_reader :dtaus, :validation_only

    def initialize(validation_only=false)
      @errors = []
      @dtaus = get_dtaus
      @validation_only = validation_only
    end

    def do_transfer_and_import(send_email=true)
      FileUtils.mkdir_p(local_download_path)
      local_file_paths = RemoteConnector.new.download_files

      local_file_paths.each do |local_file_path|
        import(local_file_path, send_email)
      end
    end


    def import(local_file_path, send_email)
      result = begin
        import_file(local_file_path)
      rescue => e
        {:errors => [e.to_s], :success => ['data lost']}
      end

      logger_res = result[:errors].blank? ? successful_import(local_file_path, send_email) : failed_import(local_file_path, result)
      Rails.logger.info "CsvExporter#import time: #{Time.now.to_formatted_s(:db)} Imported #{local_file_path}: #{logger_res}"
    end

    def import_file(file)
      line = 2
      success_rows = []
      FileUtils.mkdir_p FilesManager.tmp_mraba

      CSVReader.read(file).each do |row|
        next if row.activity.blank?
        unless row.validate_import
          errors << "#{row.activity}: #{Row::HEADERS[:umsatz_key]} #{row.umsatz_key} is not allowed"
          break
        end
        import_file_row_with_error_handling(row)
        line += 1
        break unless errors.empty?
        success_rows << row.activity
      end
      if errors.empty? and !validation_only and !dtaus.is_empty?
        dtaus.add_datei(FilesManager.mraba_csv_file)
      end
      {:success => success_rows, :errors => errors}
    end

    def import_file_row_with_error_handling(row)
      self.import_retry_count = 0
      5.times do
        self.import_retry_count += 1
        break if import_file_row(row)
      end
    end

    def import_file_row(row)
      trans = row.transaction_type
      if trans
        trans.validation_only = validation_only
        trans.dtaus = dtaus
        begin
          trans.proc_transaction
          errors << trans.errors
        rescue => e
          errors << "#{row.activity}: #{e.to_s}"
        end
        true
      else
        errors << "#{row.get_activity}: Transaction type not found"
        false
      end
    end


    private
    def successful_import(local_file_path, send_email)
      File.delete(local_file_path)
      BackendMailer.send_import_feedback('Successful Import', "Import of the file #{File.basename(local_file_path)} done.") if send_email
      "Success"
    end

    def failed_import(local_file_path, result)
      filename = File.basename(local_file_path)
      error_content = ["Import of the file #{filename} failed with errors:", result].join("\n")
      upload_error_file(filename, error_content)
      BackendMailer.send_import_feedback('Import CSV failed', error_content) if send_email
      "Imported: #{result[:success].join(', ')} Errors: #{result[:errors].join('; ')}"
    end

    def get_dtaus
      Mraba::Transaction.define_dtaus('RS', 8888888888, 99999999, 'Credit collection')
    end

    def upload_error_file(entry, result)
      FileUtils.mkdir_p FilesManager.local_data_upload_path
      error_file_local_path = FilesManager.local_data_upload_path + entry
      File.open(error_file_local_path, "w") { |f| f.write(result) }
      RemoteConnector.new.upload_file(error_file_local_path, FilesManager.error_file_upload_path(entry))
    end
  end
end
