class AddNoesToOrders < ActiveRecord::Migration[8.1]
  def change
    add_column :orders, :notes, :string
  end
end
