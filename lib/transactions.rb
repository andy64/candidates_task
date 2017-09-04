require 'csv_reader'


module CSVOperations

  class Transaction
    attr_reader :errors
    attr_accessor :validation_only, :dtaus

    def initialize(row)
      @row = row
      @errors = []
    end

    def get_sender
      sender = @row.sender
      @errors << "#{@row.activity}: Account #{@row.sender_konto} not found" unless sender
      sender
    end
  end

  class AccountTransfer < Transaction
    def proc_transaction
      add_account_transfer
    end

    private
    def add_account_transfer
      sender = get_sender
      return false unless sender

      if @row.depot_activity_id.blank?
        account_transfer = sender.credit_account_transfers.build(:amount => @row.amount.to_f, :subject => @row.import_subject, :receiver_multi => @row.receiver_konto)
        account_transfer.date = @row.entry_date.to_date
        account_transfer.skip_mobile_tan = true
      else
        account_transfer = sender.credit_account_transfers.find_by_id(@row.depot_activity_id)
        if account_transfer.nil?
          @errors << "#{@row.activity}: AccountTransfer not found"
          return
        elsif account_transfer.state != 'pending'
          @errors << "#{@row.activity}: AccountTransfer state expected 'pending' but was '#{account_transfer.state}'"
          return
        else
          account_transfer.subject = @row.import_subject
        end
      end
      if account_transfer && !account_transfer.valid?
        @errors << "#{@row.activity}: AccountTransfer validation error(s): #{account_transfer.errors.full_messages.join('; ')}"
        return false
      end
      @row.depot_activity_id.blank? ? account_transfer.save! : account_transfer.complete_transfer! unless validation_only
    end
  end

  class BankTransfer < Transaction
    def proc_transaction
      add_bank_transfer
    end

    private
    def add_bank_transfer
      sender = get_sender
      return false unless sender

      bank_transfer = sender.build_transfer(
          amount: @row.amount.to_f,
          subject: @row.import_subject,
          rec_holder: @row.receiver_name,
          rec_account_number: @row.receiver_konto,
          rec_bank_code: @row.receiver_blz
      )

      unless bank_transfer.valid?
        @errors << "#{@row.activity}: BankTransfer validation error(s): #{bank_transfer.errors.full_messages.join('; ')}"
        return false
      end
      bank_transfer.save! unless validation_only
    end
  end

  class Lastschrift < Transaction
    def proc_transaction
      add_dta_row
    end

    private
    def add_dta_row
      unless dtaus.valid_sender?(@row.sender_konto, @row.sender_blz)
        @errors << "#{@row.activity}: BLZ/Konto not valid, csv fiile not written"
        return false
      end
      holder = CSVReader.convert_acsii(@row.sender_name)
      amount_d = @row.amount.to_d.abs
      amount_d = amount_d.to_i if amount_d == amount_d.to_i
      rez = dtaus.add_buchung(@row.sender_konto, @row.sender_blz, holder, amount_d, @row.import_subject)
      @errors << 'add_buchung method failed' unless rez
      rez
    end
  end

end
