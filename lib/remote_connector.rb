# frozen_string_literal: true

require 'path_manager'

module CSVOperations
  # to create remote connections and operate file throughout them
  class RemoteConnector
    include PathManager

    def initialize(use_test_creds = false)
      @creds = if use_test_creds
                 { host: '127.0.0.1', user: 'test', port: '24', password: '11111', keys: [''] }
               elsif defined?(Rails) && Rails.env == 'production'
                 { host: 'csv.example.com/endpoint/', user: 'some-ftp-user',
                   keys: ['path-to-credentials'] }
               else
                 { host: '0.0.0.0:2020', user: 'some-ftp-user', keys: ['path-to-credentials'] }
               end
    end

    def upload_file(file, path_to_upload)
      within_session do |sftp|
        sftp.upload!(file, path_to_upload)
      end
    end

    def download_files
      path_pairs = []
      within_session do |sftp|
        remote_files_path_list(sftp).each do |filename|
          path_pairs.push %W[#{remote_csv_path}/#{filename} #{local_download_path}/#{filename}]
        end
        dls = path_pairs.map { |x| sftp.download(x[0], x[1]) }
        dls.each(&:wait)
        remove_start_remote_files(path_pairs, sftp)
      end
      path_pairs.map!(&:last) # delivered files in local download path
    end

    private

    def remove_start_remote_files(path_pairs, sftp)
      path_pairs.each do |x|
        sftp.remove!(x.first) if File.extname(x.first) == '.start'
      end
    end

    def remote_files_path_list(sftp)
      sftp.dir.glob(remote_csv_path, '*.{csv,csv.start}',
                    File::FNM_EXTGLOB).reject(&:directory?).map(&:name)
    end

    def within_session
      Net::SFTP.start(@creds[:host], @creds[:user],
                      port: @creds[:port], password: @creds[:password],
                      keys: @creds[:keys]) do |sftp|
        yield(sftp)
      end
    end
  end
end
