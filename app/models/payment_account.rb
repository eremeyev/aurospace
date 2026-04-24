# app/models/payment_account.rb
# frozen_string_literal: true

class PaymentAccount < ApplicationRecord
  belongs_to :user
  has_many :orders, dependent: :destroy
  has_many :transactions, through: :orders

  enum :account_type, [:primary, :bonus, :gift], default: :primary

  validates :balance, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :currency, presence: true, length: { is: 3 }

  def sufficient_balance?(amount)
    balance >= amount
  end

  def debit!(amount, order, description)
    return false unless sufficient_balance?(amount)

    transaction do
      update!(balance: balance - amount)
      order.update!(status: :success)

      order.transactions.create!(
        payment_account: self,
        transaction_type: :debit,
        amount: amount,
        description: description
      )
    end
    true
  end

  def credit!(amount, order, description)
    transaction do
      update!(balance: balance + amount)

      order.transactions.create!(
        payment_account: self,
        transaction_type: :credit,
        amount: amount,
        description: description
      )
    end
    true
  end
end
