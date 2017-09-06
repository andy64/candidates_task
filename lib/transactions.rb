# frozen_string_literal: true

require 'csv_reader'
require 'stringex/unidecoder'

module CSVOperations
  module Transactions
    # basic class, cannot process transactions
    class Transaction
      attr_reader :errors
      attr_accessor :validation_only, :dtaus

      def initialize(row)
        @row = row
        @errors = []
      end

      def sender_from_row
        sender = @row.sender
        @errors << "#{@row.activity}: Account #{@row.sender_konto} not found" unless sender
        sender
      end
    end

    # child transaction type
    class AccountTransfer < Transaction
      def proc_transaction
        add_account_transfer
      end

      private

      def add_account_transfer
        sender = sender_from_row
        return unless sender
        account_transfer = if @row.depot_activity_id.blank?
                             build_transfer(sender)
                           else
                             find_transfer(sender)
                           end
        return unless account_transfer
        return unless validate(account_transfer)
        save_or_complete(account_transfer) unless validation_only
      end

      def save_or_complete(account_transfer)
        if @row.depot_activity_id.blank?
          account_transfer.save!
        else
          account_transfer.complete_transfer!
        end
      end

      def build_transfer(sender)
        account_transfer = sender.credit_account_transfers.build(
          amount: @row.amount.to_f, subject: @row.import_subject,
          receiver_multi: @row.receiver_konto
        )
        account_transfer.date = @row.entry_date.to_date
        account_transfer.skip_mobile_tan = true
        account_transfer
      rescue => e
        @errors << "failed to build account transfer. ERROR: #{e.message}"
        nil
      end

      def exists(account_transfer)
        return true if account_transfer
        @errors << "#{@row.activity}: AccountTransfer not found"
        nil
      end

      def valid_state(account_transfer)
        return true if account_transfer.state == 'pending'
        body = "AccountTransfer state expected 'pending' but was"
        @errors << "#{@row.activity}: #{body} '#{account_transfer.state}'"
        nil
      end

      def find_transfer(sender)
        account_transfer = sender.credit_account_transfers.find_by_id(@row.depot_activity_id)
        return unless exists(account_transfer)
        return unless valid_state(account_transfer)
        account_transfer.subject = @row.import_subject
        account_transfer
      end

      def validate(account_transfer)
        return true if account_transfer.valid?
        messages = account_transfer.errors.full_messages.join('; ')
        @errors << "#{@row.activity}: AccountTransfer validation error(s): #{messages}"
        nil
      end
    end

    # child transaction type
    class BankTransfer < Transaction
      def proc_transaction
        add_bank_transfer
      end

      private

      def build_bank_transfer(sender)
        sender.build_transfer(
          amount: @row.amount.to_f,
          subject: @row.import_subject,
          rec_holder: @row.receiver_name,
          rec_account_number: @row.receiver_konto,
          rec_bank_code: @row.receiver_blz
        )
      end

      def get_errors(bank_transfer)
        bank_transfer.errors.full_messages.join('; ')
      end

      def add_bank_transfer
        sender = sender_from_row
        return unless sender
        bank_transfer = build_bank_transfer(sender)
        unless bank_transfer.valid?
          body = 'BankTransfer validation error(s):'
          @errors << "#{@row.activity}: #{body} #{get_errors(bank_transfer)}"
          return
        end
        bank_transfer.save! unless validation_only
      end
    end

    # child transaction type
    class Lastschrift < Transaction
      def proc_transaction
        add_dta_row
      end

      private

      def add_buchung
        holder = Stringex::Unidecoder.decode(@row.sender_name)
        amount_d = @row.amount.to_d.abs
        # not sure about expected value int or decimal
        amount_d = amount_d.to_i if amount_d == amount_d.to_i
        dtaus.add_buchung(@row.sender_konto,
                          @row.sender_blz, holder, amount_d,
                          @row.import_subject)
      end

      def add_dta_row
        unless dtaus.valid_sender?(@row.sender_konto, @row.sender_blz)
          @errors << "#{@row.activity}: BLZ/Konto not valid, csv fiile not written"
          return
        end
        rez = add_buchung
        @errors << 'add_buchung method failed' unless rez
        rez
      end
    end
  end
end
