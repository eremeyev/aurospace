class AddColumnsForIdempotency < ActiveRecord::Migration[8.1]
  def change
    add_column :payment_accounts, :lock_version, :integer, default: 0, null: false
    add_column :orders, :idempotency_key, :string
    add_column :orders, :processed_at, :datetime
    add_column :transactions, :balance_after, :decimal, precision: 12, scale: 2
  end
end
