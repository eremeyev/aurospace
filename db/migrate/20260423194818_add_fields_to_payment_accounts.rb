class AddFieldsToPaymentAccounts < ActiveRecord::Migration[8.1]
  def change
    add_column :payment_accounts, :account_type, :integer, default: 0
    add_column :payment_accounts, :currency, :string, null: false, default: 'ÚSD'
    add_column :payment_accounts, :name, :string
  end
end
