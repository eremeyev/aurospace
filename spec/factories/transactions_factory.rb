FactoryBot.define do
  # Фабрика для транзакций
  factory :transaction do
    association :payment_account
    association :order
    amount { 100.00 }
    balance_after { 900.00 }
    transaction_type { :debit }
    description { "Order transaction" }
    # idempotency_key { SecureRandom.uuid }

    trait :debit do
      transaction_type { :debit }
      amount { 100.00 }
    end

    trait :credit do
      transaction_type { :credit }
      amount { 50.00 }
    end

    trait :large do
      amount { 1000.00 }
    end
  end
end
