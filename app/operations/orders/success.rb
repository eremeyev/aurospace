# frozen_string_literal: true

module Orders
  class Success < Operation
    option :order, reader: :private
    option :payment_account, reader: :private

    TRANSACTION_TYPES = :debit

    def call
      return Failure(base: 'Order not pending') unless order.pending?
      return Failure(base: 'Top up your balance') if payment_account.balance < order.total_amount

      ApplicationRecord.transaction do
        order.success!

        update_balance!
      end

    Success(order)

    rescue ActiveRecord::RecordInvalid => e
      Failure(base: e.message)
    end

    private

    def update_balance!
      payment_account.with_lock('FOR UPDATE') do
        amount = payment_account.balance -= order.total_amount

        payment_account.save!

        payment_account.transactions.create!(
          order: order,
          amount: amount,
          transaction_type: TRANSACTION_TYPES,
          description: "Order ##{order.id} success"
        )
      end
    end
  end
end
