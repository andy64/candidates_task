require 'transactions'

module CSVOperations

  class Row < Hash
    # attr_reader :activity
    HEADERS = {sender_konto: 'SENDER_KONTO', sender_name: 'SENDER_NAME', sender_blz: 'SENDER_BLZ', receiver_blz: 'RECEIVER_BLZ',
               umsatz_key: 'UMSATZ_KEY', activity: 'ACTIVITY_ID', depot_activity_id: 'DEPOT_ACTIVITY_ID',
               amount: 'AMOUNT', receiver_name: 'RECEIVER_NAME', receiver_konto: 'RECEIVER_KONTO',
               entry_date: 'ENTRY_DATE', desc1: 'DESC1'
    }

    def initialize(items)
      self.replace items
      Row.class_eval do
        HEADERS.each { |k, v| define_method(k) { self[v] } }
      end
    end

    def sender
      Account.find_by_account_no(sender_konto)
    end

    def transaction_type
      # how to determine 1 or 2 branch is true ?
      if sender_blz == '00000000' and receiver_blz == '00000000'
        return Transactions::AccountTransfer.new(self)
      elsif sender_blz == '00000000' and umsatz_key == '10'
        return Transactions::BankTransfer.new(self)
      elsif receiver_blz == '70022200' and ['16'].include?(umsatz_key)
        return Transactions::Lastschrift.new(self)
      end
      nil
    end

    def import_subject
      subject = ''
      (1..14).to_a.each { |id| subject += self["DESC#{id}"].to_s unless self["DESC#{id}"].blank? }
      subject
    end

    def validate_import
      %w(10 16).include?(umsatz_key)
    end

  end
end

