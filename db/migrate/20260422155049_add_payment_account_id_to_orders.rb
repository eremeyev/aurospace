class AddPaymentAccountIdToOrders < ActiveRecord::Migration[8.1]
  def change
    # Указываем тип данных и добавляем внешний ключ
    add_reference :orders, :payment_account, foreign_key: { to_table: :payment_accounts }, null: true

    # Добавляем индекс для ускорения запросов
    add_index :orders, [:payment_account_id, :status]
  end
end
