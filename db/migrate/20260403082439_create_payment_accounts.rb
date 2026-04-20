class CreatePaymentAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :payment_accounts do |t|
      t.references :user, null: false, foreign_key: true
      t.decimal :balance, precision: 10, scale: 2, default: 0.0, null: false

      t.timestamps
    end
  end
end
