class CreateTransactions < ActiveRecord::Migration[8.1]
  def change
    create_table :transactions do |t|
      t.references :order, null: false, foreign_key: true
      t.references :payment_account, null: false, foreign_key: true

      t.integer :transaction_type, null: false
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.string :description, null: false

      t.timestamps
    end
  end
end
