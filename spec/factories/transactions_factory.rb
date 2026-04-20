FactoryBot.define do
  factory :transaction do
    order { nil }
    payment_account { nil }
    amount { "9.99" }
  end
end
