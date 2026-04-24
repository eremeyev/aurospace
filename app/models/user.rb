# frozen_string_literal: true

class User < ApplicationRecord
  has_many :payment_accounts, dependent: :destroy
  has_many :orders, through: :payment_accounts, dependent: :destroy
  has_many :transactions, through: :payment_accounts, dependent: :destroy

    enum :role, %i[user admin], default: :user


  before_validation :ensure_api_token, on: :create

  validates :api_token, uniqueness: true
  validates :email, presence: true, uniqueness: true

  def primary_account
    payment_accounts.find_by(account_type: :primary) || payment_accounts.first
  end

  def balance
    primary_account&.balance || 0
  end

  private

  def ensure_api_token
    self.api_token ||= SecureRandom.hex(32)
  end
end
