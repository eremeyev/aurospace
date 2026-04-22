# frozen_string_literal: true

FactoryBot.define do
  factory :order do
    transient do
      # Вспомогательные поля для создания связанных объектов
      with_payment_account { true }
      with_successful_payment { false }
    end

    # Основные поля
    total_amount { 100.00 }
    status { :pending }
    processed_at { nil }
    idempotency_key { SecureRandom.uuid }

    # Ассоциации
    association :user, factory: :user
    association :payment_account, factory: :payment_account

    # Трейты для разных статусов
    trait :pending do
      status { :pending }
      processed_at { nil }
    end

    trait :success do
      status { :success }
      processed_at { Time.current }
    end

    trait :failed do
      status { :failed }
      processed_at { Time.current }
    end

    trait :cancelled do
      status { :cancelled }
      processed_at { Time.current }
    end

    # Трейты для разных сумм
    trait :small do
      total_amount { 10.00 }
    end

    trait :medium do
      total_amount { 100.00 }
    end

    trait :large do
      total_amount { 1000.00 }
    end

    trait :huge do
      total_amount { 10_000.00 }
    end

    # Трейт с идемпотентным ключом
    trait :with_custom_idempotency do
      idempotency_key { "custom_key_#{SecureRandom.hex(8)}" }
    end

    # Трейт с обработанным заказом
    trait :processed do
      success
    end

    # Динамические фабрики
    trait :with_items do
      after(:create) do |order|
        create_list(:order_item, 3, order: order)
        order.update(total_amount: order.order_items.sum(&:price))
      end
    end

    trait :with_discount do
      after(:create) do |order|
        create(:discount, order: order, amount: 10.00)
        order.update(total_amount: order.total_amount - 10.00)
      end
    end

    # Фабрика для заказа с недостаточным балансом
    trait :insufficient_balance do
      after(:build) do |order|
        order.payment_account.update(balance: order.total_amount - 1)
      end
    end

    # Фабрика для заказа с достаточным балансом
    trait :sufficient_balance do
      after(:build) do |order|
        order.payment_account.update(balance: order.total_amount + 100)
      end
    end

    # Callbacks
    after(:build) do |order, evaluator|
      if evaluator.with_payment_account && !order.payment_account
        order.payment_account = build(:payment_account)
      end
    end

    after(:create) do |order, evaluator|
      if evaluator.with_successful_payment
        create(:transaction, :debit, order: order, payment_account: order.payment_account)
        order.update(status: :success, processed_at: Time.current)
      end
    end

    # Фабрика для тестирования конкурентности
    factory :order_for_concurrency_test do
      transient do
        initial_balance { 1000 }
      end

      total_amount { 100 }
      status { :pending }

      after(:build) do |order, evaluator|
        order.payment_account.update(balance: evaluator.initial_balance)
      end
    end
  end

  # Фабрика для элементов заказа
  factory :order_item do
    association :order
    association :product
    quantity { 1 }
    price { 50.00 }

    trait :multiple do
      quantity { 3 }
      price { 33.33 }
    end

    after(:build) do |item|
      item.price ||= item.product&.price || 50.00
    end
  end

  # Фабрика для скидок
  factory :discount do
    association :order
    amount { 10.00 }
    code { "DISCOUNT#{SecureRandom.hex(4).upcase}" }

    trait :percentage do
      discount_type { :percentage }
      amount { 10 }
    end

    trait :fixed do
      discount_type { :fixed }
      amount { 10.00 }
    end
  end
end
