module FilesManager
  def local_download_path
    defined?(Rails) ? "#{Rails.root.to_s}/private/data/download/" : "#{Dir.home}/temp_csv_importer/private/data/download/"
  end

  def remote_csv_path
    '/data/files/csv'
  end
end