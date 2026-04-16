require 'rails_helper'

RSpec.describe 'Users items', type: :request do
  describe 'GET /users' do
    let!(:user) { FactoryBot.create(:user) }

    it 'returns a list of users' do
      get('/users')

      expect(response).to have_http_status(:success)

      expect(json_response_body.count).to eq 1
      expect(json_response_body.first['email']).to eq user.email
    end
  end

  describe 'POST /users' do
    let(:email) { 'test@test.com' }
    let(:expected_attributes) { ['id', 'email'] }

    it 'create and return user' do
      post("/users", params: { user: { email: email } })

      expect(response).to have_http_status(:success)
      expect(json_response_body).to include(*expected_attributes)
    end
  end
end
