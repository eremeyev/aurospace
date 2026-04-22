# frozen_string_literal: true

class User < ApplicationRecord
  has_many :orders, dependent: :destroy
  has_many :payment_accounts, dependent: :destroy

  before_validation :ensure_api_token, on: :create

  validates :api_token, presence: true, uniqueness: true

  private

  def ensure_api_token
    self.api_token ||= SecureRandom.hex(32)
  end
end
