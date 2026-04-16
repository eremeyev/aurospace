# frozen_string_literal: true

module Orders
  class Cancel < Operation
    option :order, reader: :private
    option :transaction, reader: :private

    TRANSACTION_TYPES = :credit

    def call
      return Failure(base: 'Order not successfully') unless order.success?

      ApplicationRecord.transaction do
        order.cancelled!

        update_balance!
      end

      Success(order)

    rescue ActiveRecord::RecordInvalid => e
      Failure(base: e.message)
    end

    private

    def update_balance!
      payment_account = transaction.payment_account

      payment_account.with_lock('FOR UPDATE') do
        amount = payment_account.balance += order.total_amount
        payment_account.save!

        payment_account.transactions.create!(
          order: order,
          amount: amount,
          transaction_type: TRANSACTION_TYPES,
          description: "Refund for order #{order.id}"
        )
      end
      end
  end
end
