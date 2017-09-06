# frozen_string_literal: true

module CSVOperations
  # to send emails, write logs, operate files and errors after passed or failed imports
  class Reporter
    def initialize(local_file_path, result, send_email)
      @local_file_path = local_file_path
      @result = result
      @send_email = send_email
    end

    def report_results
      logger_res = @result[:errors].blank? ? successful_import : failed_import
      rails_log(logger_res)
    end

    private

    def successful_import
      File.delete(@local_file_path)
      text = "Import of the file '#{File.basename(@local_file_path)}' is done."
      BackendMailer.send_import_feedback('Successful Import', text) if @send_email
      'Success'
    end

    def failed_import
      filename = File.basename(@local_file_path)
      error_content = ["\nImport of the file #{filename}" \
                       "failed with errors:\n", @result[:errors].join("\n")]
      upload_error_file(filename, error_content)
      BackendMailer.send_import_feedback('Import CSV failed', error_content) if @send_email
      "Imported: #{@result[:success].join(', ')} Errors: #{@result[:errors].join('; ')}"
    end

    def upload_error_file(filename, error_content)
      FileUtils.mkdir_p local_data_upload_path
      error_file_local_path = local_data_upload_path + filename
      File.open(error_file_local_path, 'w') { |f| f.write(error_content) }
      RemoteConnector.new.upload_file(error_file_local_path, error_file_upload_path(filename))
    end

    def rails_log(logger_res)
      Rails.logger.info("CsvExporter#import time: #{Time.now.to_formatted_s(:db)}" \
                        "Imported #{@local_file_path}: #{logger_res}")
    end
  end
end
