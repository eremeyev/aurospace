# frozen_string_literal: true

# require 'ostruct'

FactoryBot.define do
  factory :order_success_setup, class: 'OpenStruct' do
    transient do
      initial_balance { 500.00 }
      order_amount { 100.00 }
      status { :pending }
      with_idempotency { true }
    end

    after(:build) do |_, evaluator|
      user = create(:user)
      payment_account = create(:payment_account, user: user, balance: evaluator.initial_balance)

      order = create(:order,
        user: user,
        status: evaluator.status,
        total_amount: evaluator.order_amount,
        payment_account: payment_account,
        idempotency_key: (evaluator.with_idempotency ? SecureRandom.uuid : nil)
      )

      setup.order = order
      setup.payment_account = payment_account
      setup.user = user
    end

    initialize_with { attributes }

    trait :sufficient_balance do
      initial_balance { 500.00 }
      order_amount { 100.00 }
    end

    trait :insufficient_balance do
      initial_balance { 50.00 }
      order_amount { 100.00 }
    end

    trait :already_processed do
      status { :success }
      after(:build) do |_, evaluator|
        evaluator.order&.update(processed_at: Time.current)
      end
    end

    trait :concurrent do
      after(:build) do |_, evaluator|
        evaluator.payment_account.update(lock_version: 0)
      end
    end
  end
end
