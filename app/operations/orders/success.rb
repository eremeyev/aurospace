# frozen_string_literal: true

module Orders
  class Success < Operation
    include ActiveModel::Validations

    option :order, reader: :private
    option :payment_account, reader: :private
    option :idempotency_key, reader: :private, optional: true

    MAX_RETRIES = 3
    DEBIT_TYPE = 'debit'.freeze

    def call
      # 1. Идемпотентность — возвращаем результат, если уже обработано
      return handle_idempotent_request if idempotency_key && order.processed_at?

      validate_prerequisites!

      retry_on_optimistic_lock do
        ApplicationRecord.transaction(isolation: :repeatable_read) do
          # 2. Ещё раз проверяем состояние (защита от race condition)
          order.reload
          payment_account.reload

          return failure_result('Order not pending') unless order.pending?
          return failure_result('Insufficient funds') if payment_account.balance < order.total_amount

          # 3. Атомарное обновление баланса через optimistic lock
          debit_amount = order.total_amount
          new_balance = payment_account.balance - debit_amount

          payment_account.update!(
            balance: new_balance,
            lock_version: payment_account.lock_version # автоинкремент
          )

          # 4. Создание транзакции и апдейт заказа в одной транзакции
          create_debit_transaction!(payment_account, debit_amount, new_balance)
          order.update!(
            status: :success,
            processed_at: Time.current,
            idempotency_key: idempotency_key
          )

          Success(order)
        end
      end
    rescue ActiveRecord::StaleObjectError
      # Optimistic lock conflict — повторяем
      retry
    rescue ActiveRecord::RecordInvalid => e
      failure_result(e.message)
    end

    private

    def validate_prerequisites!
      raise ArgumentError, 'Order must be persisted' unless order.persisted?
      raise ArgumentError, 'Payment account must be persisted' unless payment_account.persisted?
    end

    def handle_idempotent_request
      return failure_result('Order already processed but failed') unless order.processed_at? && order.success?

      Success(order) # возвращаем тот же результат
    end

    def retry_on_optimistic_lock(&block)
      retries = 0
      begin
        block.call
      rescue ActiveRecord::StaleObjectError => e
        retries += 1
        retry if retries <= MAX_RETRIES
        raise "Optimistic lock conflict after #{MAX_RETRIES} retries: #{e.message}"
      end
    end

    def create_debit_transaction!(account, amount, balance_after)
      account.transactions.create!(
        order: order,
        amount: amount,
        balance_after: balance_after,
        transaction_type: DEBIT_TYPE,
        description: "Order ##{order.id} success",
        # idempotency_key: idempotency_key # опционально в транзакциях
      )
    end

    def failure_result(message)
      Failure(base: message)
    end
  end
end
