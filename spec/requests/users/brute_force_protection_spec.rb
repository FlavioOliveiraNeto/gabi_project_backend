require 'rails_helper'

RSpec.describe "Proteção contra força bruta", type: :request do
  let(:password) { "SenhaSegura@123!" }
  let!(:user)    { create(:user, :client, password: password) }

  def attempt_login(email: user.email, attempt_password: "senha-errada", ip: nil)
    headers = { "Content-Type" => "application/json" }
    headers["REMOTE_ADDR"] = ip if ip

    post user_session_path,
         params: { user: { email: email, password: attempt_password } },
         headers: headers,
         as: :json
  end

  describe "Devise :lockable" do
    before { Rack::Attack.enabled = false }
    after  { Rack::Attack.enabled = true }

    it "está habilitado no modelo" do
      expect(User.devise_modules).to include(:lockable)
    end

    it "conta as tentativas falhas na conta" do
      expect { attempt_login(ip: "10.0.0.1") }
        .to change { user.reload.failed_attempts }.by(1)
    end

    it "zera o contador depois de um login bem-sucedido" do
      2.times { |i| attempt_login(ip: "10.0.0.#{i}") }

      attempt_login(attempt_password: password, ip: "10.0.0.99")

      expect(user.reload.failed_attempts).to eq(0)
    end

    it "trava a conta ao atingir maximum_attempts" do
      Devise.maximum_attempts.times { |i| attempt_login(ip: "10.1.0.#{i}") }

      expect(user.reload).to be_access_locked
    end

    it "rejeita a senha correta enquanto a conta está travada" do
      Devise.maximum_attempts.times { |i| attempt_login(ip: "10.2.0.#{i}") }

      attempt_login(attempt_password: password, ip: "10.2.1.1")

      expect(response).to have_http_status(:unauthorized)
    end

    it "não revela que a conta está travada (modo paranoid)" do
      Devise.maximum_attempts.times { |i| attempt_login(ip: "10.3.0.#{i}") }

      attempt_login(attempt_password: password, ip: "10.3.1.1")

      expect(json_body["error"]).not_to match(/locked|travada|bloqueada/i)
    end

    it "destrava sozinha depois de unlock_in" do
      Devise.maximum_attempts.times { |i| attempt_login(ip: "10.4.0.#{i}") }
      expect(user.reload).to be_access_locked

      travel(Devise.unlock_in + 1.minute) do
        attempt_login(attempt_password: password, ip: "10.4.1.1")

        expect(response).to have_http_status(:ok)
      end
    end

    it "trava por conta, não por IP — o ataque distribuído não escapa" do
      Devise.maximum_attempts.times { |i| attempt_login(ip: "192.168.#{i}.#{i}") }

      expect(user.reload).to be_access_locked
    end
  end

  describe "throttle por e-mail alvo" do
    it "retorna 429 depois do limite, mesmo variando o IP a cada tentativa" do
      11.times { |i| attempt_login(ip: "203.0.113.#{i}") }

      expect(response).to have_http_status(:too_many_requests)
    end

    it "normaliza o e-mail (caixa e espaços) para não ser burlado" do
      10.times { |i| attempt_login(email: user.email, ip: "203.0.114.#{i}") }

      attempt_login(email: "  #{user.email.upcase}  ", ip: "203.0.114.200")

      expect(response).to have_http_status(:too_many_requests)
    end

    it "não afeta outro e-mail" do
      other = create(:user, :client, password: password)
      11.times { |i| attempt_login(ip: "203.0.115.#{i}") }

      attempt_login(email: other.email, attempt_password: password, ip: "203.0.115.200")

      expect(response).not_to have_http_status(:too_many_requests)
    end
  end

  describe "throttle na escrita de senha" do
    it "limita a submissão do token de reset (PUT /users/password)" do
      11.times do
        put user_password_path,
            params: { user: { reset_password_token: "chute-#{rand(10**6)}", password: password, password_confirmation: password } },
            as: :json
      end

      expect(response).to have_http_status(:too_many_requests)
    end

    it "limita o pedido de reset por e-mail alvo" do
      6.times do |i|
        post user_password_path,
             params: { user: { email: user.email } },
             headers: { "REMOTE_ADDR" => "198.51.100.#{i}" },
             as: :json
      end

      expect(response).to have_http_status(:too_many_requests)
    end
  end

  describe "rede de segurança global" do
    it "limita requisições autenticadas em volume" do
      headers = auth_headers(user)

      301.times { get clients_dashboard_path, headers: headers }

      expect(response).to have_http_status(:too_many_requests)
    end

    it "não limita o health check" do
      301.times { get "/up" }

      expect(response).not_to have_http_status(:too_many_requests)
    end
  end

  describe "resposta de throttle" do
    it "informa Retry-After" do
      6.times { attempt_login }

      expect(response.headers["Retry-After"]).to be_present
    end

    it "responde em JSON com a chave :error" do
      6.times { attempt_login }

      expect(json_body).to include("error")
    end
  end
end
