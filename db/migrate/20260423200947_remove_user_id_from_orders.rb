class RemoveUserIdFromOrders < ActiveRecord::Migration[8.1]
  def change
    remove_column :orders, :user_id
  end
end
