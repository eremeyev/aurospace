# frozen_string_literal: true

describe Users::Builder do
  describe '#call' do
    subject(:called) { described_class.new(email: new_email).call }

    let(:email) { 'test@example.com' }
    let!(:user) { FactoryBot.create(:user, email: email) }

    context 'when user does not exist' do
      let(:new_email) { 'test2@example.com' }

      it { is_expected.to be_success }

      it 'creates user with payment account' do
        expect { called }
          .to change(User, :count).by(1)
          .and change(PaymentAccount, :count).by(1)
      end
    end

    context 'when user exist' do
      let(:new_email) { email }

      it { is_expected.to be_failure }

      it { expect { called }.not_to change(User, :count) }
    end
  end
end
