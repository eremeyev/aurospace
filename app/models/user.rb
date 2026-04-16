# frozen_string_literal: true

class User < ApplicationRecord
  has_many :orders, dependent: :destroy
  has_many :payment_accounts, dependent: :destroy
end
