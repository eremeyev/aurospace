# app/models/order.rb
# frozen_string_literal: true

class Order < ApplicationRecord
  enum :status, [:pending, :success, :cancelled, :refunded]

  belongs_to :payment_account
  has_one :user, through: :payment_account
  has_many :transactions, dependent: :destroy

  validates :total_amount, presence: true, numericality: { greater_than: 0 }
  validates :status, presence: true

  before_validation :set_default_status, on: :create

  def pay!
    return false unless pending?

    debited = payment_account.debit!(total_amount, self, "Оплата заказа ##{id}")
    return true if debited

    errors.add(:base, 'Заказ не оплачен')
    false
  end

  def refund!
    return false unless success?

    credited = payment_account.credit!(total_amount, self, "Возврат за заказ ##{id}")
    if credited
      update!(status: :refunded)
      return true
    end

    errors.add(:base, 'Заказ не оплачен')
    false
  end

  def cancel!
    return false unless pending?
    update!(status: :cancelled)
    true
  end

  def pay_with_idempotency!(key)
    return true if idempotency_key == key && success?

    transaction do
      update!(idempotency_key: key) if key.present?
      pay!
    end
  end

  private

  def set_default_status
    self.status ||= :pending
  end
end
