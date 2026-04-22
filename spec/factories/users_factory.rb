FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "email#{n}@email.com" }
    api_token { SecureRandom.hex(32) }
  end
end
