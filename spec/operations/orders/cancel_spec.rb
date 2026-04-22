# frozen_string_literal: true

describe Orders::Cancel do
  describe '#call' do
    subject(:called) do
      described_class.new(order: order, transaction: transaction).call
    end

    let(:user) { FactoryBot.create(:user) }
    let(:balance) { 90 }
    let(:payment_account) { FactoryBot.create(:payment_account, user: user, balance: balance) }
    let(:order) { FactoryBot.create(:order, payment_account: payment_account, user: user, status: :success, total_amount: 10) }
    let(:transaction) do
      FactoryBot.create(:transaction,
                        order: order,
                        payment_account: payment_account,
                        amount: 10,
                        transaction_type: :debit,
                        description: 'order success')
    end

    context 'happy path' do
      it { is_expected.to be_success }

      it 'order status is cancelled' do
        expect { called }.to change { order.status }.from('success').to('cancelled')
      end

      it 'change amount for payment account to 0' do
        expect { called }.to change { payment_account.reload.balance }.to(100)
      end
    end
  end
end
