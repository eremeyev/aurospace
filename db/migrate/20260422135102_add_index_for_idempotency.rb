class AddIndexForIdempotency < ActiveRecord::Migration[8.1]
  def change
    add_index :orders, :idempotency_key, unique: true, name: 'index_orders_on_idempotency_key'
    add_index :transactions, [:payment_account_id, :created_at], order: { created_at: :desc }
  end
end
