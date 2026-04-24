# spec/models/transaction_spec.rb
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Transaction, type: :model do
  describe 'associations' do
    it { should belong_to(:order) }
    it { should belong_to(:payment_account) }
    it { should have_one(:user).through(:payment_account) }
  end

  describe 'validations' do
    subject { build(:transaction) }

    it { should validate_presence_of(:amount) }
    it { should validate_numericality_of(:amount).is_greater_than(0) }
    it { should validate_presence_of(:description) }
    it { should define_enum_for(:transaction_type).with_values(debit: 0, credit: 1) }
  end

  describe 'scopes' do
    let(:user) { create(:user) }
    let(:payment_account) { create(:payment_account, user: user) }
    let(:order) { create(:order, payment_account: payment_account) }

    before do
      create(:transaction, :debit, order: order, payment_account: payment_account, created_at: 1.day.ago)
      create(:transaction, :credit, order: order, payment_account: payment_account, created_at: 2.days.ago)
      create(:transaction, :debit, order: order, payment_account: payment_account, created_at: 1.hour.ago)
    end

    describe '.debits' do
      it 'returns only debit transactions' do
        expect(Transaction.debits.count).to eq(2)
        Transaction.debits.each do |transaction|
          expect(transaction.debit?).to be true
        end
      end
    end

    describe '.credits' do
      it 'returns only credit transactions' do
        expect(Transaction.credits.count).to eq(1)
        Transaction.credits.each do |transaction|
          expect(transaction.credit?).to be true
        end
      end
    end

    describe '.recent' do
      it 'returns transactions ordered by created_at desc' do
        recent = Transaction.recent
        expect(recent.first.created_at).to be > recent.last.created_at
      end
    end
  end

  describe '#reversal!' do
    let(:user) { create(:user) }
    let(:account) { create(:payment_account, user: user, balance: 100.00) }
    let(:order) { create(:order, :success, payment_account: account, total_amount: 50.00) }
    let!(:transaction) { create(:transaction, :debit, order: order, payment_account: account, amount: 50.00) }

    context 'when transaction is reversible' do
      it 'creates a reversal transaction' do
        expect {
          transaction.reversal!
        }.to change(Transaction, :count).by(1)
      end

      it 'creates transaction with opposite type' do
        reversal = transaction.reversal!
        expect(reversal.credit?).to be true
        expect(reversal.amount).to eq(transaction.amount)
      end

      it 'updates description' do
        reversal = transaction.reversal!
        expect(reversal.description).to include('Сторно')
      end

      it 'returns reversal transaction' do
        reversal = transaction.reversal!
        expect(reversal).to be_a(Transaction)
        expect(reversal.id).not_to eq(transaction.id)
      end
    end

    context 'when transaction is too old' do
      let(:user) { create(:user) }
      let(:account) { create(:payment_account, user: user, balance: 100.00) }
      let(:order) { create(:order, :success, payment_account: account, total_amount: 50.00) }
      let(:transaction) { create(:transaction, :debit, order: order, payment_account: account, created_at: 31.days.ago) }

      it 'returns false' do
        expect(transaction.reversal!).to be false
      end

      it 'does not create transaction' do
        expect {
          transaction.reversal!
        }.to_not change(Transaction, :count)
      end
    end
  end
end
