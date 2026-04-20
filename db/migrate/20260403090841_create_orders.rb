class CreateOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :orders do |t|
      t.references :user, null: false, foreign_key: true

      t.integer :status, null: false, default: 0
      t.decimal :total_amount, precision: 10, scale: 2, default: 0.0, null: false

      t.timestamps
    end
  end
end
