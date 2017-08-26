require 'files_manager'

class RemoteConnector
include FilesManager

  def initialize
    #throw error if Rails is not defined
    @sftp_server = if defined? Rails and Rails.env == 'production'
                     'csv.example.com/endpoint/'
                   else
                     '0.0.0.0:2020'
                   end
    @ftp_user = "some-ftp-user"
  end

  def download_files
    Net::SFTP.start(@sftp_server, @ftp_user, :keys => ["path-to-credentials"]) do |sftp|
      remote_files_list = sftp.dir.entries(remote_csv_path).map { |e| e.name }
      downloaded_files = []
      #why sorting?
      remote_files_list.sort.each do |filename|
        next unless File.extname(filename) == '.csv'
        next unless remote_files_list.include?(filename + '.start')

        local_file_path = local_download_path + filename
        remote_file_path = remote_csv_path + filename

        sftp.download!(remote_file_path, local_file_path)
        downloaded_files.push local_file_path
        sftp.remove!(remote_file_path + '.start')
      end
      downloaded_files
    end
  end
end