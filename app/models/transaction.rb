# frozen_string_literal: true

class Transaction < ApplicationRecord
  enum :transaction_type, [:debit, :credit]

  belongs_to :order
  belongs_to :payment_account

  validates :description, presence: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
end
