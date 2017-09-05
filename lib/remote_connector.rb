require 'path_manager'

module CSVOperations
  class RemoteConnector
    include PathManager


    def initialize(use_test_creds=false)
      if use_test_creds
        @creds = {host: '127.0.0.1', user: 'test', port: '24', password: '11111', keys: ['']}
      else
        @creds = {}
        if defined? Rails and Rails.env == 'production'
          @creds[:host] = 'csv.example.com/endpoint/'
        else
          @creds[:host] = '0.0.0.0'
          @creds[:port] = 2020
        end
        @creds[:user] = 'some-ftp-user'
        @creds[:keys] = ['path-to-credentials']
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
          path_pairs.push ["#{remote_csv_path}/" + filename, "#{local_download_path}/" + filename]
        end
        dls = path_pairs.map { |x| sftp.download(x[0], x[1]) }
        dls.each { |d| d.wait }
        remove_start_remote_files(path_pairs, sftp)
      end
      path_pairs.map! { |x| x.last } #delivered files in local download path
    end

    private

    def remove_start_remote_files(path_pairs, sftp)
      path_pairs.each do |x|
        sftp.remove!(x.first) if File.extname(x.first)=='.start'
      end
    end

    def remote_files_path_list(sftp)
      sftp.dir.glob(remote_csv_path, '*.{csv,csv.start}', File::FNM_EXTGLOB).reject { |x| x.directory? }.map { |e| e.name }
    end

    def within_session
      Net::SFTP.start(@creds[:host], @creds[:user], port: @creds[:port], password: @creds[:password],
                      keys: @creds[:keys]) do |sftp|
        yield(sftp)
      end
    end

  end
end


