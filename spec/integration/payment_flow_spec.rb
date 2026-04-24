# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Payment Flow', type: :integration do
  let(:user) { create(:user) }
  let(:account) { create(:payment_account, :primary, user: user, balance: 500.00) }

  describe 'complete payment cycle' do
    it 'handles successful payment and refund' do
      # Создаем заказ
      order = create(:order, payment_account: account, total_amount: 100.00)

      # Оплачиваем
      expect(order.pay!).to be true
      expect(order.reload.status).to eq('success')
      expect(account.reload.balance).to eq(400.00)
      expect(order.transactions.count).to eq(1)

      # Возвращаем
      expect(order.refund!).to be true
      expect(order.reload.status).to eq('refunded')
      expect(account.reload.balance).to eq(500.00)
      expect(order.transactions.count).to eq(2)
      expect(order.transactions.last.credit?).to be true
    end

    it 'handles cancellation before payment' do
      order = create(:order, payment_account: account, total_amount: 100.00)

      expect(order.cancel!).to be true
      expect(order.reload.status).to eq('cancelled')
      expect(account.reload.balance).to eq(500.00)
      expect(order.transactions).to be_empty
    end

    it 'handles insufficient balance' do
      order = create(:order, payment_account: account, total_amount: 600.00)

      expect(order.pay!).to be false
      expect(order.reload.status).to eq('pending')
      expect(account.reload.balance).to eq(500.00)
      expect(order.transactions).to be_empty
    end
  end

  describe 'multiple accounts scenario' do
    let(:bonus_account) { create(:payment_account, :bonus, user: user, balance: 100.00) }

    it 'allows selecting different payment accounts' do
      order1 = create(:order, payment_account: account, total_amount: 100.00)
      order2 = create(:order, payment_account: bonus_account, total_amount: 50.00)

      expect(order1.pay!).to be true
      expect(account.reload.balance).to eq(400.00)

      expect(order2.pay!).to be true
      expect(bonus_account.reload.balance).to eq(50.00)

      # Заказы пользователя
      expect(user.orders.count).to eq(2)
      expect(user.orders).to include(order1, order2)
    end
  end
end
