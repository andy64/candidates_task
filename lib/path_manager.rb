# frozen_string_literal: true

module CSVOperations
  # to store paths to files that are in use by other classes
  module PathManager
    def local_download_path
      if defined?(Rails)
        "#{Rails.root}/private/data/download/"
      else
        "#{Dir.home}/temp_csv_importer/private/data/download/"
      end
    end

    def remote_csv_path
      '/data/files/csv'
    end

    def source_path
      if defined? Rails
        "#{Rails.root}/private/upload/"
      else
        Dir.home + '/private/upload/'
      end
    end

    def path_and_name
      "#{source_path}/csv/tmp_mraba/DTAUS#{Time.now.strftime('%Y%m%d_%H%M%S')}"
    end

    def error_file_upload_path(entry)
      "/data/files/batch_processed/#{entry}"
    end

    def local_data_upload_path
      if defined?(Rails)
        "#{Rails.root}/private/data/upload/"
      else
        Dir.home + '/private/data/upload/'
      end
    end

    def tmp_mraba
      "#{source_path}/csv/tmp_mraba"
    end

    def mraba_csv_file
      "#{path_and_name}_201_mraba.csv"
    end
  end
end
