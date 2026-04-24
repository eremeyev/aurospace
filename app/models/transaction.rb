# app/models/transaction.rb
# frozen_string_literal: true

class Transaction < ApplicationRecord
  enum :transaction_type, [:debit, :credit]

  belongs_to :order
  belongs_to :payment_account
  has_one :user, through: :payment_account

  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :description, presence: true

  scope :debits, -> { where(transaction_type: :debit) }
  scope :credits, -> { where(transaction_type: :credit) }
  scope :recent, -> { order(created_at: :desc) }

  def reversal!
    return false unless reversible?

    Transaction.create!(
      order: order,
      payment_account: payment_account,
      transaction_type: opposite_type,
      amount: amount,
      description: "Сторно: #{description}"
    )
  end

  private

  def reversible?
    created_at > 30.days.ago
  end

  def opposite_type
    debit? ? :credit : :debit
  end
end
