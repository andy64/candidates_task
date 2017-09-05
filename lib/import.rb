# encoding: utf-8
require_relative 'remote_connector'
require_relative 'transactions'
require_relative 'row'
require_relative 'csv_reader'

module CSVOperations


  class Import
    attr_accessor :errors
    attr_reader :dtaus, :validation_only, :send_email, :import_retry_count

    def initialize(send_email=false, validation_only=false)
      @errors = []
      @dtaus = get_dtaus
      @validation_only = validation_only
      @send_email = send_email
      @import_retry_count = 0
    end

    def do_transfer_and_import(send_email=true)
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
        {:success => ['data lost'], :errors => [e.to_s] }
      end

      logger_res = result[:errors].blank? ? successful_import(local_file_path) : failed_import(local_file_path, result)
      Rails.logger.info "CsvExporter#import time: #{Time.now.to_formatted_s(:db)} Imported #{local_file_path}: #{logger_res}"
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
      if errors.empty? and !validation_only and !dtaus.is_empty?
        dtaus.add_datei(PathManager.mraba_csv_file)
      end
      errors.unshift *validation_errors
      {:success => success_rows, :errors => errors}
    end

    def repeat_row_import(row)
      @import_retry_count = 0
      5.times do
        @import_retry_count += 1
        if import_row(row)
          @import_retry_count.times{ errors.pop }
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
    def successful_import(local_file_path)
      File.delete(local_file_path)
      BackendMailer.send_import_feedback('Successful Import', "Import of the file #{File.basename(local_file_path)} done.") if send_email
      'Success'
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
      File.open(error_file_local_path, 'w') { |f| f.write(result) }
      RemoteConnector.new.upload_file(error_file_local_path, FilesManager.error_file_upload_path(entry))
    end
  end
end
