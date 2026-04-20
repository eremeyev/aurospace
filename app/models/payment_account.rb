# frozen_string_literal: true

class PaymentAccount < ApplicationRecord
  belongs_to :user

  has_many :transactions, dependent: :destroy

  validates :balance, presence: true, numericality: { greater_than_or_equal_to: 0 }
end
