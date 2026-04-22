require 'rails_helper'

RSpec.describe 'Orders API', type: :request do
  let!(:user) { FactoryBot.create(:user) }
  let!(:payment_account) { FactoryBot.create(:payment_account, user: user, balance: 60) }

  describe 'POST /purchase' do
    let!(:order) { FactoryBot.create(:order, user: user, status: :pending, total_amount: 50) }
    let(:expected_attributes) { %w[status total_amount id] }

    it 'returns a list of users' do
      post("/orders/#{order.id}/purchase",
           params: { payment_account_id: payment_account.id },
           headers: auth_headers(user))

      expect(response).to have_http_status(:success)
      expect(json_response_body).to include(*expected_attributes)
    end
  end

  describe 'POST /cancel' do
    let!(:order) { FactoryBot.create(:order, user: user, status: :success, total_amount: 50) }
    let!(:transaction) do
      FactoryBot.create(:transaction,
                        order: order,
                        payment_account: payment_account,
                        amount: 50,
                        transaction_type: :debit,
                        description: 'description')
    end
    let(:expected_attributes) { %w[status total_amount] }

    it 'create and return user' do
      post("/orders/#{order.id}/cancel", headers: auth_headers(user))

      expect(response).to have_http_status(:success)
      expect(json_response_body).to include(*expected_attributes)
    end
  end
end
