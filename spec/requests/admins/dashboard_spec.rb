require 'rails_helper'

RSpec.describe "Admins::Dashboard", type: :request do
  let(:admin) { create(:user, role: :admin) }
  let!(:client_1) { create(:user, role: :client, email: "cliente1@teste.com") }
  let!(:client_2) { create(:user, role: :client, email: "cliente2@teste.com") }
  
  let!(:note) { create(:clinical_note, user: client_1, content: "Sessão produtiva") }

  describe "GET /admins/dashboard" do
    context "quando usuário é admin" do
      before { sign_in admin }

      it "retorna a lista de clientes com suas notas" do
        get admins_dashboard_path

        expect(response).to have_http_status(:ok)
        
        json = JSON.parse(response.body)
        
        expect(json['clients'].size).to eq(2)
        
        client_data = json['clients'].find { |c| c['email'] == "cliente1@teste.com" }
        expect(client_data['notes']).to be_present
        expect(client_data['notes'].first['content']).to eq("Sessão produtiva")
      end
    end

    context "quando usuário é client" do
      it "bloqueia o acesso e redireciona (conforme Pundit)" do
        sign_in client_1
        get admins_dashboard_path
        
        expect(response).to redirect_to(root_path)
      end
    end
  end
end