# frozen_string_literal: true

class Order < ApplicationRecord
  # pending - создан
  # success - оплачен
  # cancelled - отменен
  enum :status, [:pending, :success, :cancelled]

  belongs_to :user

  has_many :transactions, dependent: :destroy

  validates :total_amount, presence: true, numericality: { greater_than: 0 }
end
