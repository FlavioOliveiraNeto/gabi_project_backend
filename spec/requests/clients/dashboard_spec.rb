require 'rails_helper'

RSpec.describe "Clients::Dashboard", type: :request do
  let(:client) { create(:user, role: :client, sessions_count: 5, google_meet_link: "https://meet.google.com/abc-123") }

  describe "GET /clients/dashboard" do
    context "quando o usuário está logado como cliente" do
      before { sign_in client }

      it "retorna sucesso e os dados do cliente em JSON" do
        get clients_dashboard_path

        expect(response).to have_http_status(:ok)
        
        json = JSON.parse(response.body)
        
        expect(json['user']['email']).to eq(client.email)
        expect(json['user']['sessions_count']).to eq(5)
        expect(json['user']['google_meet_link']).to eq("https://meet.google.com/abc-123")
      end
    end

    context "quando o usuário não está logado" do
      it "retorna erro de não autorizado (401)" do
        get clients_dashboard_path, as: :json
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end