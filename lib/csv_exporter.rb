# encoding: utf-8

require 'net/sftp'
# require 'iconv'
require 'csv'
require 'remote_connector'

class Import
  attr_accessor :import_retry_count

  def initialize()
    @errors = []
  end

  def do_transfer_and_import(send_email=true)
    FileUtils.mkdir_p(local_download_path)
    local_file_paths = RemoteConnector.new.download_files

    local_file_paths.each do |local_file_path|
      result = import(local_file_path)
      filename =  File.basename(local_file_path)

      if result == 'Success'
        File.delete(local_file_path)
        BackendMailer.send_import_feedback('Successful Import', "Import of the file #{filename} done.") if send_email
      else
        error_content = ["Import of the file #{filename} failed with errors:", result].join("\n")
        upload_error_file(filename, error_content)
        BackendMailer.send_import_feedback('Import CSV failed', error_content) if send_email
        break
      end
    end



  end


  def import(file, validation_only=false)
    begin
      result = import_file(file, validation_only)
    rescue => e
      result = {:errors => [e.to_s], :success => ['data lost']}
    end

    if result[:errors].blank?
      result = "Success"
    else
      result = "Imported: #{result[:success].join(', ')} Errors: #{result[:errors].join('; ')}"
    end

    Rails.logger.info "CsvExporter#import time: #{Time.now.to_formatted_s(:db)} Imported #{file}: #{result}"

    result
  end

  def import_file(file, validation_only=false)
    @errors = []
    line = 2
    source_path = "#{Rails.root.to_s}/private/upload"
    path_and_name = "#{source_path}/csv/tmp_mraba/DTAUS#{Time.now.strftime('%Y%m%d_%H%M%S')}"

    FileUtils.mkdir_p "#{source_path}/csv"
    FileUtils.mkdir_p "#{source_path}/csv/tmp_mraba"

    @dtaus = Mraba::Transaction.define_dtaus('RS', 8888888888, 99999999, 'Credit collection')
    success_rows = []
    import_rows = CSV.read(file, {:col_sep => ';', :headers => true, :skip_blanks => true}).map { |r| [r.to_hash['ACTIVITY_ID'], r.to_hash] }

    import_rows.each do |index, row|
      next if index.blank?
      break unless validate_import_row(row)
      errors, dtaus = import_file_row_with_error_handling(row, validation_only, @errors, @dtaus)
      line += 1
      break unless @errors.empty?
      success_rows << row['ACTIVITY_ID']
    end

    if @errors.empty? and !validation_only
      @dtaus.add_datei("#{path_and_name}_201_mraba.csv") unless @dtaus.is_empty?
    end

    {:success => success_rows, :errors => @errors}
  end

  def import_file_row(row, validation_only, errors, dtaus)
    case transaction_type(row)
      when 'AccountTransfer' then
        add_account_transfer(row, validation_only)
      when 'BankTransfer' then
        add_bank_transfer(row, validation_only)
      when 'Lastschrift' then
        add_dta_row(dtaus, row, validation_only)
      else
        errors << "#{row['ACTIVITY_ID']}: Transaction type not found"
    end

    [errors, dtaus]
  end

  def import_file_row_with_error_handling(row, validation_only, errors, dtaus)
    error_text = nil
    self.import_retry_count = 0
    5.times do
      self.import_retry_count += 1
      error_text = nil
      begin
        import_file_row(row, validation_only, errors, dtaus)
        break
      rescue => e
        error_text = "#{row['ACTIVITY_ID']}: #{e.to_s}"
        break
      end
    end
    errors << error_text if error_text

    [errors, dtaus]
  end

  def validate_import_row(row)
    errors = []
    @errors << "#{row['ACTIVITY_ID']}: UMSATZ_KEY #{row['UMSATZ_KEY']} is not allowed" unless %w(10 16).include? row['UMSATZ_KEY']
    @errors += errors

    errors.size == 0
  end

  def transaction_type(row)
    if row['SENDER_BLZ'] == '00000000' and row['RECEIVER_BLZ'] == '00000000'
      return 'AccountTransfer'
    elsif row['SENDER_BLZ'] == '00000000' and row['UMSATZ_KEY'] == '10'
      return 'BankTransfer'
    elsif row['RECEIVER_BLZ'] == '70022200' and ['16'].include? row['UMSATZ_KEY']
      return 'Lastschrift'
    else
      return false
    end
  end

  def get_sender(row)
    sender = Account.find_by_account_no(row['SENDER_KONTO'])

    if sender.nil?
      @errors << "#{row['ACTIVITY_ID']}: Account #{row['SENDER_KONTO']} not found"
    end

    sender
  end

  def add_account_transfer(row, validation_only)
    sender = get_sender(row)
    return @errors.last unless sender

    if row['DEPOT_ACTIVITY_ID'].blank?
      account_transfer = sender.credit_account_transfers.build(:amount => row['AMOUNT'].to_f, :subject => import_subject(row), :receiver_multi => row['RECEIVER_KONTO'])
      account_transfer.date = row['ENTRY_DATE'].to_date
      account_transfer.skip_mobile_tan = true
    else
      account_transfer = sender.credit_account_transfers.find_by_id(row['DEPOT_ACTIVITY_ID'])
      if account_transfer.nil?
        @errors << "#{row['ACTIVITY_ID']}: AccountTransfer not found"
        return
      elsif account_transfer.state != 'pending'
        @errors << "#{row['ACTIVITY_ID']}: AccountTransfer state expected 'pending' but was '#{account_transfer.state}'"
        return
      else
        account_transfer.subject = import_subject(row)
      end
    end
    if account_transfer && !account_transfer.valid?
      @errors << "#{row['ACTIVITY_ID']}: AccountTransfer validation error(s): #{account_transfer.errors.full_messages.join('; ')}"
    elsif !validation_only
      row['DEPOT_ACTIVITY_ID'].blank? ? account_transfer.save! : account_transfer.complete_transfer!
    end
  end

  def add_bank_transfer(row, validation_only)
    sender = get_sender(row)
    return @errors.last unless sender

    bank_transfer = sender.build_transfer(
        :amount => row['AMOUNT'].to_f,
        :subject => import_subject(row),
        :rec_holder => row['RECEIVER_NAME'],
        :rec_account_number => row['RECEIVER_KONTO'],
        :rec_bank_code => row['RECEIVER_BLZ']
    )

    if !bank_transfer.valid?
      @errors << "#{row['ACTIVITY_ID']}: BankTransfer validation error(s): #{bank_transfer.errors.full_messages.join('; ')}"
    elsif !validation_only
      bank_transfer.save!
    end
  end

  def add_dta_row(dtaus, row, validation_only)
    if !dtaus.valid_sender?(row['SENDER_KONTO'], row['SENDER_BLZ'])
      return @errors << "#{row['ACTIVITY_ID']}: BLZ/Konto not valid, csv fiile not written"
    end
    holder = Iconv.iconv('ascii//translit', 'utf-8', row['SENDER_NAME']).to_s.gsub(/[^\w^\s]/, '')
    dtaus.add_buchung(row['SENDER_KONTO'], row['SENDER_BLZ'], holder, BigDecimal(row['AMOUNT']).abs, import_subject(row))
  end

  def import_subject(row)
    subject = ""

    for id in (1..14).to_a
      subject += row["DESC#{id}"].to_s unless row["DESC#{id}"].blank?
    end

    subject
  end

  private


  def upload_error_file(entry, result)
    FileUtils.mkdir_p "#{Rails.root.to_s}/private/data/upload"
    error_file = "#{Rails.root.to_s}/private/data/upload/#{entry}"
    File.open(error_file, "w") do |f|
      f.write(result)
    end
    Net::SFTP.start(@sftp_server, "some-ftp-user", :keys => ["path-to-credentials"]) do |sftp|
      sftp.upload!(error_file, "/data/files/batch_processed/#{entry}")
    end
  end

end


class CsvExporter
  def self.transfer_and_import(send_email = true)
    im = Import.new
    im.do_transfer_and_import(send_email)
  end
end

Net::SFTP.start('localhost:22', 'andy') do |ftp|
  ftp
end
CsvExporter.transfer_and_import