require 'path_manager'

module CSVOperations
  class RemoteConnector
    include PathManager

    def initialize
      @sftp_server = if defined? Rails and Rails.env == 'production'
                       'csv.example.com/endpoint/'
                     else
                       '0.0.0.0:2020'
                     end
      @ftp_user = 'some-ftp-user'
      @keys = ['path-to-credentials']
    end

    def upload_file(file, path_to_upload)
      within_sftp_sesson do |sftp|
        sftp.upload!(file, path_to_upload)
      end
    end

    def download_files
      within_sftp_sesson do |sftp|
        path_pairs = []
        remote_files_path_list.each do |path|
          filename = File.basename(path)
          path_pairs.push [remote_csv_path + filename, local_download_path + filename]
        end
        dls = path_pairs.map { |x| sftp.download(x[0], x[1]) }
        dls.each { |d| d.wait }
        path_pairs.each { |x| sftp.remove!(x.first + '.start') }
        path_pairs.map { |x| x.last }
      end
    end

    private
    def remote_files_path_list(sftp)
      sftp.dir.glob(remote_csv_path, '*.{csv,start}').map { |e| e.name }
    end
    def within_sftp_sesson
      Net::SFTP.start(@sftp_server, @ftp_user, keys: @keys  ) do |sftp|
        yield(sftp)
      end
    end

  end
end


