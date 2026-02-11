require 'rails_helper'

RSpec.describe "Autenticação", type: :request do
  let(:user) { create(:user) }

  it "permite login com credenciais válidas" do
    post user_session_path, params: {
      user: { email: user.email, password: user.password }
    }

    expect(response).to be_redirect
  end
end