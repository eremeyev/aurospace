# spec/models/payment_account_spec.rb
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PaymentAccount, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
    it { should have_many(:orders).dependent(:destroy) }
    it { should have_many(:transactions).through(:orders) }
  end

  describe 'validations' do
    subject { build(:payment_account) }

    it { should validate_presence_of(:balance) }
    it { should validate_numericality_of(:balance).is_greater_than_or_equal_to(0) }
    it { should validate_presence_of(:currency) }
    it { should validate_length_of(:currency).is_equal_to(3) }
    it { should define_enum_for(:account_type).with_values(primary: 0, bonus: 1, gift: 2) }
  end

  describe '#sufficient_balance?' do
    let(:user) { create(:user) }
    let(:account) { create(:payment_account, user: user, balance: 100.00) }

    it 'returns true when balance is sufficient' do
      expect(account.sufficient_balance?(50.00)).to be true
    end

    it 'returns true when balance exactly equals amount' do
      expect(account.sufficient_balance?(100.00)).to be true
    end

    it 'returns false when balance is insufficient' do
      expect(account.sufficient_balance?(150.00)).to be false
    end
  end

  describe '#debit!' do
    let(:user) { create(:user) }
    let(:account) { create(:payment_account, user: user, balance: 200.00) }
    let(:order) { create(:order, payment_account: account, total_amount: 50.00) }

    context 'with sufficient balance' do
      it 'decreases balance' do
        expect {
          account.debit!(50.00, order, 'Test debit')
        }.to change { account.reload.balance }.from(200.00).to(150.00)
      end

      it 'creates a transaction' do
        expect {
          account.debit!(50.00, order, 'Test debit')
        }.to change(Transaction, :count).by(1)
      end

      it 'updates order status to success' do
        account.debit!(50.00, order, 'Test debit')
        expect(order.reload.status).to eq('success')
      end

      it 'returns true' do
        expect(account.debit!(50.00, order, 'Test debit')).to be true
      end

      it 'creates transaction with correct attributes' do
        account.debit!(50.00, order, 'Test debit')
        transaction = order.transactions.last
        expect(transaction.amount).to eq(50.00)
        expect(transaction.transaction_type).to eq('debit')
        expect(transaction.description).to eq('Test debit')
      end
    end

    context 'with insufficient balance' do
      it 'does not change balance' do
        expect {
          account.debit!(250.00, order, 'Test debit')
        }.to_not change { account.reload.balance }
      end

      it 'does not create transaction' do
        expect {
          account.debit!(250.00, order, 'Test debit')
        }.to_not change(Transaction, :count)
      end

      it 'returns false' do
        expect(account.debit!(250.00, order, 'Test debit')).to be false
      end
    end

    context 'with invalid amount' do
      it 'raises error when amount is negative' do
        expect {
          account.debit!(-10.00, order, 'Test debit')
        }.to raise_error(ActiveRecord::RecordInvalid)
      end

      it 'raises error when amount is zero' do
        expect {
          account.debit!(0, order, 'Test debit')
        }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end
  end

  describe '#credit!' do
    let(:user) { create(:user) }
    let(:account) { create(:payment_account, user: user, balance: 100.00) }
    let(:order) { create(:order, payment_account: account, total_amount: 50.00, status: :success) }

    it 'increases balance' do
      expect {
        account.credit!(50.00, order, 'Test credit')
      }.to change { account.reload.balance }.from(100.00).to(150.00)
    end

    it 'creates a transaction' do
      expect {
        account.credit!(50.00, order, 'Test credit')
      }.to change(Transaction, :count).by(1)
    end

    it 'creates transaction with correct type' do
      account.credit!(50.00, order, 'Test credit')
      transaction = order.transactions.last
      expect(transaction.transaction_type).to eq('credit')
    end

    it 'returns true' do
      expect(account.credit!(50.00, order, 'Test credit')).to be true
    end
  end
end
