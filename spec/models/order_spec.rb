# spec/models/order_spec.rb
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Order, type: :model do
  describe 'associations' do
    it { should belong_to(:payment_account) }
    it { should have_one(:user).through(:payment_account) }
    it { should have_many(:transactions).dependent(:destroy) }
  end

  describe 'validations' do
    subject { build(:order) }

    it { should validate_presence_of(:total_amount) }
    it { should validate_numericality_of(:total_amount).is_greater_than(0) }
    it { should define_enum_for(:status).with_values(pending: 0, success: 1, cancelled: 2, refunded: 3) }
  end

  describe 'callbacks' do
    it 'sets default status to pending on create' do
      user = create(:user)
      order = Order.new(total_amount: 100.00, payment_account: create(:payment_account, user: user))
      order.valid?
      expect(order.status).to eq('pending')
    end
  end

  describe '#pay!' do
    let(:user) { create(:user) }
    let(:account) { create(:payment_account, user: user, balance: 200.00) }
    let(:order) { create(:order, payment_account: account, total_amount: 50.00, status: :pending) }

    context 'when payment is successful' do
      it 'changes status to success' do
        expect {
          order.pay!
        }.to change(order, :status).from('pending').to('success')
      end

      it 'decreases account balance' do
        expect {
          order.pay!
        }.to change { account.reload.balance }.from(200.00).to(150.00)
      end

      it 'creates transaction' do
        expect {
          order.pay!
        }.to change(Transaction, :count).by(1)
      end

      it 'returns true' do
        expect(order.pay!).to be true
      end
    end

    context 'when payment fails due to insufficient balance' do
      let(:user) { create(:user) }
      let(:account) { create(:payment_account, user: user, balance: 30.00) }

      it 'does not change status' do
        expect {
          order.pay!
        }.to_not change(order, :status)
      end

      it 'does not change balance' do
        expect {
          order.pay!
        }.to_not change { account.reload.balance }
      end

      it 'does not create transaction' do
        expect {
          order.pay!
        }.to_not change(Transaction, :count)
      end

      it 'returns false' do
        expect(order.pay!).to be false
      end

      it 'adds error message' do
        order.pay!
        expect(order.errors[:base]).to be_present
      end
    end

    context 'when order is already paid' do
      let(:order) { create(:order, :success, payment_account: account) }

      it 'returns false' do
        expect(order.pay!).to be false
      end
    end
  end

  describe '#refund!' do
    let(:user) { create(:user) }
    let(:account) { create(:payment_account, user: user, balance: 100.00) }
    let(:order) { create(:order, :success, payment_account: account, total_amount: 50.00) }

    context 'when refund is successful' do
      it 'changes status to refunded' do
        expect {
          order.refund!
        }.to change(order, :status).from('success').to('refunded')
      end

      it 'increases account balance' do
        expect {
          order.refund!
        }.to change { account.reload.balance }.from(100.00).to(150.00)
      end

      it 'creates credit transaction' do
        expect {
          order.refund!
        }.to change(Transaction, :count).by(1)

        transaction = order.transactions.last
        expect(transaction.transaction_type).to eq('credit')
      end

      it 'returns true' do
        expect(order.refund!).to be true
      end
    end

    context 'when order is not paid' do
      let(:order) { create(:order, :pending, payment_account: account) }

      it 'returns false' do
        expect(order.refund!).to be false
      end

      it 'does not change balance' do
        expect {
          order.refund!
        }.to_not change { account.reload.balance }
      end
    end

    context 'when order is already refunded' do
      let(:order) { create(:order, :refunded, payment_account: account) }

      it 'returns false' do
        expect(order.refund!).to be false
      end
    end
  end

  describe '#cancel!' do
    let(:user) { create(:user) }
    let(:account) { create(:payment_account, user: user, balance: 100.00) }

    context 'when order is pending' do
      let(:order) { create(:order, :pending, payment_account: account) }

      it 'changes status to cancelled' do
        expect {
          order.cancel!
        }.to change(order, :status).from('pending').to('cancelled')
      end

      it 'does not affect balance' do
        expect {
          order.cancel!
        }.to_not change { account.reload.balance }
      end

      it 'does not create transaction' do
        expect {
          order.cancel!
        }.to_not change(Transaction, :count)
      end

      it 'returns true' do
        expect(order.cancel!).to be true
      end
    end

    context 'when order is already paid' do
      let(:order) { create(:order, :success, payment_account: account) }

      it 'returns false' do
        expect(order.cancel!).to be false
      end
    end
  end
end
