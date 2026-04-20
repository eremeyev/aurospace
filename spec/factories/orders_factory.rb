FactoryBot.define do
  factory :order do
    user { nil }
    status { 1 }
    total_amount { "9.99" }
  end
end
