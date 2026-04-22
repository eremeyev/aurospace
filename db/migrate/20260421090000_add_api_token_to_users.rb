class AddApiTokenToUsers < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    add_column :users, :api_token, :string

    say_with_time "Backfilling users.api_token" do
      migration_user = Class.new(ActiveRecord::Base) { self.table_name = "users" }
      migration_user.reset_column_information

      migration_user.where(api_token: nil).in_batches(of: 1_000) do |relation|
        relation.each do |user|
          user.update_columns(api_token: SecureRandom.hex(32))
        end
      end
    end

    change_column_null :users, :api_token, false
    add_index :users, :api_token, unique: true, algorithm: :concurrently
  end

  def down
    remove_index :users, :api_token if index_exists?(:users, :api_token)
    remove_column :users, :api_token
  end
end
