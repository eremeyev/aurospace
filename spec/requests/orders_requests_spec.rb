# spec/requests/orders_requests_spec.rb
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Orders API', type: :request do
  let!(:user) { create(:user) }
  let!(:payment_account) { create(:payment_account, :primary, user: user, balance: 500.00) }
  let(:headers) { authentication_headers(user) }

  # Хелпер для аутентификации
  def authentication_headers(user)
    {
      'Authorization' => "Bearer #{user.api_token}",
      'Content-Type' => 'application/json'
    }
  end

  describe 'GET /orders' do
    before do
      create_list(:order, 3, payment_account: payment_account)
      create(:order, payment_account: payment_account, total_amount: 1000.00)
    end

    it 'returns all orders for authenticated user' do
      get '/orders', headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['orders'].size).to eq(4)
      expect(json['orders'].first).to include('id', 'total_amount', 'status')
    end

    it 'returns paginated results' do
      get '/orders', params: { page: 1, per_page: 2 }, headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['orders'].size).to eq(2)
      expect(json['meta']).to include('current_page', 'total_pages', 'total_count')
    end

    it 'returns orders in descending order' do
      get '/orders', headers: headers

      json = JSON.parse(response.body)
      order_ids = json['orders'].map { |o| o['id'] }

      expect(order_ids).to eq(order_ids.sort.reverse)
    end

    context 'when user is not authenticated' do
      it 'returns unauthorized' do
        get '/orders'

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'GET /orders/:id' do
    let(:order) { create(:order, :pending, payment_account: payment_account) }

    it 'returns order with transactions' do
      get "/orders/#{order.id}", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json).to include('id', 'total_amount', 'status')
      expect(json).to include('payment_account', 'transactions')
    end

    context 'when order belongs to another user' do
      let(:other_user) { create(:user) }
      let(:other_account) { create(:payment_account, user: other_user) }
      let(:other_order) { create(:order, payment_account: other_account) }

      it 'returns forbidden' do
        get "/orders/#{other_order.id}", headers: headers

        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when order does not exist' do
      it 'returns not found' do
        get '/orders/999999', headers: headers

        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'POST /orders' do
    let(:valid_params) do
      {
        order: {
          total_amount: 150.00,
          notes: 'Test order',
          payment_account_id: payment_account.id
        }
      }
    end

    it 'creates a new order' do
      expect {
        post '/orders', params: valid_params.to_json, headers: headers
      }.to change(Order, :count).by(1)

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)

      expect(json['order']['total_amount']).to eq('150.0')
      expect(json['order']['status']).to eq('pending')
      expect(json['message']).to eq('Order created successfully')
    end

    it 'sets default status to pending' do
      post '/orders', params: valid_params.to_json, headers: headers

      json = JSON.parse(response.body)
      expect(json['order']['status']).to eq('pending')
    end

    context 'with invalid params' do
      let(:invalid_params) do
        {
          order: {
            total_amount: -50.00,
            payment_account_id: payment_account.id
          }
        }
      end

      it 'returns unprocessable entity' do
        post '/orders', params: invalid_params.to_json, headers: headers

        expect(response).to have_http_status(:unprocessable_content)
        json = JSON.parse(response.body)
        expect(json['errors']).to be_present
      end
    end

    context 'without payment_account_id' do
      let(:params_without_account) do
        {
          order: {
            total_amount: 150.00
          }
        }
      end

      it 'uses primary payment account' do
        post '/orders', params: params_without_account.to_json, headers: headers

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json['order']['payment_account_id']).to eq(payment_account.id)
      end
    end
  end

  describe 'POST /orders/:id/purchase' do
    let!(:order) { create(:order, :pending, payment_account: payment_account, total_amount: 100.00) }

    it 'successfully processes payment' do
      expect {
        post "/orders/#{order.id}/purchase", headers: headers
      }.to change(Transaction, :count).by(1)

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['success']).to be true
      expect(json['message']).to eq('Payment processed successfully')
      expect(json['order']['status']).to eq('success')
      expect(json['balance']).to eq('400.0')
    end

    it 'decreases payment account balance' do
      expect {
        post "/orders/#{order.id}/purchase", headers: headers
      }.to change { payment_account.reload.balance }.from(500.00).to(400.00)
    end

    context 'when insufficient balance' do
      let(:order) { create(:order, payment_account: payment_account, total_amount: 600.00) }

      it 'returns error' do
        post "/orders/#{order.id}/purchase", headers: headers

        expect(response).to have_http_status(:unprocessable_content)
        json = JSON.parse(response.body)

        expect(json['success']).to be false
        expect(json['error']).to eq('Payment failed')
        expect(order.reload.status).to eq('pending')
      end

      it 'does not create transaction' do
        expect {
          post "/orders/#{order.id}/purchase", headers: headers
        }.to_not change(Transaction, :count)
      end
    end

    context 'when order already paid' do
      let(:order) { create(:order, :success, payment_account: payment_account) }

      it 'returns error' do
        post "/orders/#{order.id}/purchase", headers: headers

        expect(response).to have_http_status(:unprocessable_content)
        json = JSON.parse(response.body)

        expect(json['error']).to eq('Order cannot be purchased')
        expect(json['details']).to include("Order status is success")
      end
    end

    context 'with idempotency key' do
      let(:idempotency_key) { 'unique-key-123' }
      let(:headers_with_idempotency) { headers.merge('Idempotency-Key' => idempotency_key) }

      it 'processes payment only once' do
        expect {
          post "/orders/#{order.id}/purchase", headers: headers_with_idempotency
          post "/orders/#{order.id}/purchase", headers: headers_with_idempotency
        }.to change(Transaction, :count).by(1)

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json['message']).to eq('Payment already processed (idempotent request)')
      end
    end

    context 'when order belongs to another user' do
      let(:other_user) { create(:user) }
      let(:other_account) { create(:payment_account, user: other_user) }
      let(:other_order) { create(:order, payment_account: other_account) }

      it 'returns forbidden' do
        post "/orders/#{other_order.id}/purchase", headers: headers

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'POST /orders/:id/cancel' do
    let(:order) { create(:order, :pending, payment_account: payment_account) }

    it 'cancels pending order' do
      post "/orders/#{order.id}/cancel", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['success']).to be true
      expect(json['message']).to eq('Order cancelled successfully')
      expect(order.reload.status).to eq('cancelled')
    end

    it 'does not change payment account balance' do
      expect {
        post "/orders/#{order.id}/cancel", headers: headers
      }.to_not change { payment_account.reload.balance }
    end

    it 'does not create transaction' do
      expect {
        post "/orders/#{order.id}/cancel", headers: headers
      }.to_not change(Transaction, :count)
    end

    context 'when order is already paid' do
      let(:order) { create(:order, :success, payment_account: payment_account) }

      it 'returns error' do
        post "/orders/#{order.id}/cancel", headers: headers

        expect(response).to have_http_status(:unprocessable_content)
        json = JSON.parse(response.body)

        expect(json['success']).to be false
        expect(json['error']).to eq('Cannot cancel order')
        expect(json['details']).to include('Only pending orders can be cancelled')
      end
    end

    context 'when order is already cancelled' do
      let(:order) { create(:order, :cancelled, payment_account: payment_account) }

      it 'returns error' do
        post "/orders/#{order.id}/cancel", headers: headers

        expect(response).to have_http_status(:unprocessable_content)
        expect(JSON.parse(response.body)['success']).to be false
      end
    end
  end

  describe 'POST /orders/:id/refund' do
    let(:order) { create(:order, :success, payment_account: payment_account, total_amount: 100.00) }

    before do
      # Создаем транзакцию оплаты
      order.pay!
    end

    it 'refunds successful order' do
      expect {
        post "/orders/#{order.id}/refund", headers: headers
      }.to change(Transaction, :count).by(1)

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json['success']).to be true
      expect(json['message']).to eq('Refund processed successfully')
      expect(order.reload.status).to eq('refunded')
      expect(json['refunded_amount']).to eq('100.0')
    end

    it 'returns money to payment account' do
      initial_balance = payment_account.balance

      post "/orders/#{order.id}/refund", headers: headers

      expect(payment_account.reload.balance).to eq(initial_balance + 100.00)
      expect(JSON.parse(response.body)['new_balance']).to eq((initial_balance + 100.00).to_s)
    end

    context 'when order is pending' do
      let(:order1) { create(:order, status: :pending, payment_account: payment_account) }

      it 'returns error' do
        post "/orders/#{order1.id}/refund", headers: headers

        expect(response).to have_http_status(:unprocessable_content)
        json = JSON.parse(response.body)

        expect(json['success']).to be false
        expect(json['error']).to eq('Cannot refund order')
        expect(json['details']).to include('Only successful orders can be refunded')
      end
    end

    context 'when order is already refunded' do
      let(:order) { create(:order, :refunded, payment_account: payment_account) }

      it 'returns error' do
        post "/orders/#{order.id}/refund", headers: headers

        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context 'when refund time limit exceeded' do
      let(:order) { create(:order, :success, payment_account: payment_account, created_at: 31.days.ago) }

      it 'returns error if time limit is configured' do
        # Если в контроллере есть проверка временного лимита
        post "/orders/#{order.id}/refund", headers: headers

        # Может вернуть ошибку или обработать в зависимости от логики
        expect(response.status).to be_between(400, 422)
      end
    end
  end

  describe 'GET /orders/:id/status' do
    let(:order) { create(:order, payment_account: payment_account) }

    it 'returns order status' do
      get "/orders/#{order.id}/status", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)

      expect(json).to include(
        'order_id' => order.id,
        'status' => order.status,
        'total_amount' => order.total_amount.to_s,
        'payment_account_id' => payment_account.id
      )
    end

    it 'returns timestamps' do
      get "/orders/#{order.id}/status", headers: headers

      json = JSON.parse(response.body)
      expect(json).to include('created_at', 'updated_at')
    end
  end

  # describe 'POST /orders/:id/partial_refund' do
  #   let(:order) { create(:order, :success, payment_account: payment_account, total_amount: 200.00) }

  #   before { order.pay! }

  #   it 'processes partial refund' do
  #     post "/orders/#{order.id}/partial_refund",
  #          params: { amount: 50.00 }.to_json,
  #          headers: headers

  #     expect(response).to have_http_status(:ok)
  #     json = JSON.parse(response.body)

  #     expect(json['success']).to be true
  #     expect(json['refunded_amount']).to eq(50.00)
  #     expect(json['remaining_amount']).to eq(150.00)
  #   end

  #   context 'with invalid amount' do
  #     it 'rejects zero amount' do
  #       post "/orders/#{order.id}/partial_refund",
  #            params: { amount: 0 }.to_json,
  #            headers: headers

  #       expect(response).to have_http_status(:unprocessable_content)
  #       json = JSON.parse(response.body)
  #       expect(json['error']).to include('greater than 0')
  #     end

  #     it 'rejects amount exceeding order total' do
  #       post "/orders/#{order.id}/partial_refund",
  #            params: { amount: 300.00 }.to_json,
  #            headers: headers

  #       expect(response).to have_http_status(:unprocessable_content)
  #       json = JSON.parse(response.body)
  #       expect(json['error']).to include('exceeds order total')
  #     end
  #   end

  #   context 'when order is not successful' do
  #     let(:order) { create(:order, :pending, payment_account: payment_account) }

  #     it 'returns error' do
  #       post "/orders/#{order.id}/partial_refund",
  #            params: { amount: 50.00 }.to_json,
  #            headers: headers

  #       expect(response).to have_http_status(:unprocessable_content)
  #       json = JSON.parse(response.body)
  #       expect(json['error']).to include('Only successful orders')
  #     end
  #   end
  # end
end
