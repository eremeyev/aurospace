# frozen_string_literal: true

module Users
  class Builder < Operation
    option :email, reader: :private

    def call
      ApplicationRecord.transaction do
        user = User.new(email: email)
        user.save!

        user.payment_accounts.create!

        Success(user)
      end

    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
      Failure(base: e.message)
    end
  end
end
