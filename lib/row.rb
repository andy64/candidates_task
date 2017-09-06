# frozen_string_literal: true

require_relative 'transactions'

module CSVOperations
  # represents the row from csv file as hash extension
  class Row < Hash
    HEADERS = { sender_konto: 'SENDER_KONTO', sender_name: 'SENDER_NAME',
                sender_blz: 'SENDER_BLZ', receiver_blz: 'RECEIVER_BLZ',
                umsatz_key: 'UMSATZ_KEY', activity: 'ACTIVITY_ID',
                depot_activity_id: 'DEPOT_ACTIVITY_ID', amount: 'AMOUNT',
                receiver_name: 'RECEIVER_NAME', receiver_konto: 'RECEIVER_KONTO',
                entry_date: 'ENTRY_DATE', desc1: 'DESC1' }.freeze

    def initialize(items)
      replace items
      Row.class_eval do
        HEADERS.each { |k, v| define_method(k) { self[v] } }
      end
    end

    def sender
      Account.find_by_account_no(sender_konto)
    rescue
      nil
    end

    def transaction
      if sender_blz == '00000000'
        return Transactions::AccountTransfer.new(self) if receiver_blz == '00000000'
        return Transactions::BankTransfer.new(self) if umsatz_key == '10'
      end
      if receiver_blz == '70022200' && ['16'].include?(umsatz_key)
        return Transactions::Lastschrift.new(self)
      end
      nil
    end

    def import_subject
      subject = ''
      (1..14).to_a.each { |id| subject += self["DESC#{id}"].to_s unless self["DESC#{id}"].blank? }
      subject
    end

    def import_valid?
      %w[10 16].include?(umsatz_key)
    end
  end
end
