# frozen_string_literal: true

describe Orders::Success do
  describe '#call' do
    subject(:called) do
      described_class.new(order: order, payment_account: payment_account).call
    end

    let(:user) { FactoryBot.create(:user) }
    let(:balance) { 100 }
    let(:payment_account) { FactoryBot.create(:payment_account, user: user, balance: balance) }
    let(:order) { FactoryBot.create(:order, user: user, status: :pending, total_amount: 10) }

    context 'happy path' do
      it { is_expected.to be_success }

      it 'order status is success' do
        expect { called }.to change { order.status }.from('pending').to('success')
      end

      it 'change amount for payment account to 0' do
        expect { called }.to change { payment_account.reload.balance }.to(90)
      end
    end

    context 'sad path' do
      let(:balance) { 5 }

      it { is_expected.to be_failure }
    end
  end
end
