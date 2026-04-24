# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'associations' do
    it { should have_many(:payment_accounts).dependent(:destroy) }
    it { should have_many(:orders).through(:payment_accounts) }
    it { should have_many(:transactions).through(:payment_accounts) }
  end

  describe 'validations' do
    before do
      User.create!(api_token: "test-token-123", email: "test@example.com") # Add other required fields
    end

    it { should validate_uniqueness_of(:api_token) }
    # it { should validate_presence_of(:api_token) }

    it 'automatically generates api_token on create' do
      user = User.new
      user.valid?
      expect(user.api_token).to be_present
    end

    it 'does not change existing api_token' do
      user = create(:user, api_token: 'custom-token', email: 'a@a.com')
      user.valid?
      expect(user.api_token).to eq('custom-token')
    end
  end

  describe '#primary_account' do
    let(:user) { create(:user) }

    context 'when user has primary account' do
      let!(:primary_account) { create(:payment_account, user: user, account_type: :primary) }
      let!(:bonus_account) { create(:payment_account, user: user, account_type: :bonus) }

      it 'returns primary account' do
        expect(user.primary_account).to eq(primary_account)
      end
    end

    context 'when user has no primary account' do
      let!(:first_account) { create(:payment_account, user: user, created_at: 1.day.ago) }
      let!(:second_account) { create(:payment_account, user: user, created_at: 1.hour.ago) }

      it 'returns first created account' do
        expect(user.primary_account).to eq(first_account)
      end
    end

    context 'when user has no accounts' do
      it 'returns nil' do
        expect(user.primary_account).to be_nil
      end
    end
  end

  describe '#balance' do
    let(:user) { create(:user) }

    context 'when user has primary account' do
      let!(:account) { create(:payment_account, user: user, balance: 500.00) }

      it 'returns primary account balance' do
        expect(user.balance).to eq(500.00)
      end
    end

    context 'when user has no primary account but has other accounts' do
      let!(:account) { create(:payment_account, user: user, balance: 300.00, account_type: :bonus) }

      it 'returns first account balance' do
        expect(user.balance).to eq(300.00)
      end
    end

    context 'when user has no accounts' do
      it 'returns 0' do
        expect(user.balance).to eq(0)
      end
    end
  end
end
