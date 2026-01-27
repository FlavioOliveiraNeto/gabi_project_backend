RSpec.describe "Admin::Dashboard", type: :request do
  context "quando usuário é admin" do
    let(:admin) { create(:user, role: :admin) }

    it "permite acesso" do
      sign_in admin
      get admins_dashboard_path, headers: headers

      expect(response).to have_http_status(:ok)
    end
  end

  context "quando usuário é client" do
    let(:client) { create(:user, role: :client) }

    it "bloqueia acesso" do
      sign_in client
      get admins_dashboard_path, headers: headers

      expect(response).to redirect_to(root_path)
    end
  end
end
