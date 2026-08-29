require "rails_helper"

RSpec.describe User, type: :model do
  subject(:user) { build(:user) }

  describe "validações" do
    context "com dados válidos" do
      it "é válido" do
        expect(user).to be_valid
      end
    end

    describe "presença de campos obrigatórios" do
      it "é inválido sem name" do
        user.name = nil
        expect(user).to be_invalid
        expect(user.errors[:name]).to be_present
      end

      it "é inválido sem email" do
        user.email = nil
        expect(user).to be_invalid
        expect(user.errors[:email]).to be_present
      end

      it "é inválido sem password" do
        user.password = nil
        expect(user).to be_invalid
        expect(user.errors[:password]).to be_present
      end

      it "é inválido sem role" do
        user.role = nil
        expect(user).to be_invalid
        expect(user.errors[:role]).to be_present
      end
    end

    describe "formato do email" do
      it "é inválido com email sem @" do
        user.email = "emailinvalido.com"
        expect(user).to be_invalid
        expect(user.errors[:email]).to be_present
      end

      it "é inválido com email sem domínio" do
        user.email = "usuario@"
        expect(user).to be_invalid
        expect(user.errors[:email]).to be_present
      end

      it "é inválido com email com espaços" do
        user.email = "usuario @clinica.com"
        expect(user).to be_invalid
        expect(user.errors[:email]).to be_present
      end

      it "é válido com email bem formatado" do
        user.email = "gabriella@clinicafelix.com.br"
        expect(user).to be_valid
      end
    end

    describe "unicidade do email" do
      let!(:existente) { create(:user, email: "duplicado@clinica.com") }

      it "é inválido quando email já existe" do
        user.email = "duplicado@clinica.com"
        expect(user).to be_invalid
        expect(user.errors[:email]).to be_present
      end

      it "é inválido quando email já existe em caixa diferente (case insensitive)" do
        user.email = "DUPLICADO@CLINICA.COM"
        expect(user).to be_invalid
        expect(user.errors[:email]).to be_present
      end
    end

    describe "tamanho da senha" do
      it "é inválido com senha menor que 12 caracteres" do
        user.password = "Senha@123!"
        expect(user).to be_invalid
        expect(user.errors[:password]).to be_present
      end

      it "é válido com senha de exatamente 12 caracteres" do
        user.password = "Senha@123456"
        expect(user).to be_valid
      end

      it "é válido com senha longa" do
        user.password = "SenhaSegura@2025!"
        expect(user).to be_valid
      end
    end

    describe "inclusão de role" do
      it "é válido com role therapist" do
        user.role = :therapist
        expect(user).to be_valid
      end

      it "é válido com role client" do
        user.role = :client
        expect(user).to be_valid
      end

      it "levanta ArgumentError com role desconhecido" do
        expect { user.role = :admin }.to raise_error(ArgumentError)
      end
    end

    describe "google_meet_link" do
      it "é válido em branco (opcional)" do
        user.google_meet_link = ""
        expect(user).to be_valid
      end

      it "é válido com URL HTTPS do Google Meet" do
        user.google_meet_link = "https://meet.google.com/abc-defg-hij"
        expect(user).to be_valid
      end

      it "aceita host em maiúsculas (case-insensitive)" do
        user.google_meet_link = "https://MEET.GOOGLE.COM/abc-defg-hij"
        expect(user).to be_valid
      end

      it "é inválido com http:// (não-HTTPS)" do
        user.google_meet_link = "http://meet.google.com/abc-defg-hij"
        expect(user).to be_invalid
        expect(user.errors[:google_meet_link]).to be_present
      end

      it "é inválido com host arbitrário (open redirect / phishing)" do
        user.google_meet_link = "https://evil.example.com/phish"
        expect(user).to be_invalid
        expect(user.errors[:google_meet_link]).to be_present
      end

      it "é inválido com subdomínio forjado (meet.google.com.evil.com)" do
        user.google_meet_link = "https://meet.google.com.evil.com/x"
        expect(user).to be_invalid
        expect(user.errors[:google_meet_link]).to be_present
      end

      it "é inválido com string que não é URL" do
        user.google_meet_link = "not a url at all"
        expect(user).to be_invalid
        expect(user.errors[:google_meet_link]).to be_present
      end
    end
  end

  describe "associações" do
    it { is_expected.to have_many(:audit_logs) }
    it { is_expected.to have_many(:sessions) }
    it { is_expected.to have_many(:recurring_schedules) }
  end

  describe "#therapist?" do
    context "quando role é therapist" do
      let(:user) { build(:user, :therapist) }

      it "retorna true" do
        expect(user.therapist?).to be true
      end
    end

    context "quando role é client" do
      let(:user) { build(:user, :client) }

      it "retorna false" do
        expect(user.therapist?).to be false
      end
    end
  end

  describe "#client?" do
    context "quando role é client" do
      let(:user) { build(:user, :client) }

      it "retorna true" do
        expect(user.client?).to be true
      end
    end

    context "quando role é therapist" do
      let(:user) { build(:user, :therapist) }

      it "retorna false" do
        expect(user.client?).to be false
      end
    end
  end

  describe "#must_change_password?" do
    context "quando must_change_password é false" do
      let(:user) { build(:user, must_change_password: false) }

      it "retorna false" do
        expect(user.must_change_password?).to be false
      end
    end

    context "quando must_change_password é true" do
      let(:user) { build(:user, :must_change_password) }

      it "retorna true" do
        expect(user.must_change_password?).to be true
      end
    end
  end

  describe "#active_for_authentication?" do
    context "quando a conta está ativa" do
      let(:user) { build(:user, active: true) }

      it "retorna true" do
        expect(user.active_for_authentication?).to be true
      end
    end

    context "quando a conta está desativada" do
      let(:user) { build(:user, :inactive) }

      it "retorna false" do
        expect(user.active_for_authentication?).to be false
      end
    end
  end

  describe "#inactive_message" do
    context "quando a conta está ativa" do
      let(:user) { build(:user, active: true) }

      it "delega a mensagem padrão do Devise" do
        expect(user.inactive_message).to eq(:inactive)
      end
    end

    context "quando a conta está desativada" do
      let(:user) { build(:user, :inactive) }

      it "retorna :account_inactive" do
        expect(user.inactive_message).to eq(:account_inactive)
      end
    end

    it "possui tradução cadastrada para :account_inactive" do
      expect(I18n.t("devise.failure.account_inactive")).not_to match(/translation missing/i)
    end
  end

  describe "segurança da senha" do
    let(:user) { create(:user, password: "SenhaSegura@123!") }

    it "não armazena a senha em texto plano" do
      expect(user.encrypted_password).not_to eq("SenhaSegura@123!")
    end

    it "armazena a senha como hash bcrypt (começa com $2)" do
      expect(user.encrypted_password).to start_with("$2")
    end

    it "dois usuários com a mesma senha têm encrypted_password diferentes (salt único)" do
      outro = create(:user, password: "SenhaSegura@123!")
      expect(user.encrypted_password).not_to eq(outro.encrypted_password)
    end
  end

  describe "normalização do email" do
    it "converte email para downcase antes de salvar" do
      user = create(:user, email: "GABRIELLA@CLINICA.COM.BR")
      expect(user.reload.email).to eq("gabriella@clinica.com.br")
    end

    it "mantém o email em downcase quando já está em minúsculas" do
      user = create(:user, email: "gabriella@clinica.com.br")
      expect(user.reload.email).to eq("gabriella@clinica.com.br")
    end
  end

  describe "valores padrão" do
    let(:novo_usuario) { described_class.new }

    it "must_change_password começa como false" do
      expect(novo_usuario.must_change_password).to be false
    end

    it "active começa como true" do
      expect(novo_usuario.active).to be true
    end
  end

  describe "senha temporária (criado pela terapeuta)" do
    context "quando criado sem must_change_password explícito" do
      it "must_change_password é false por padrão" do
        user = build(:user)
        expect(user.must_change_password).to be false
      end
    end

    context "quando criado com must_change_password: true" do
      let(:user_com_senha_temp) { build(:user, :must_change_password) }

      it "must_change_password é true" do
        expect(user_com_senha_temp.must_change_password).to be true
      end

      it "o usuário é válido mesmo com must_change_password true" do
        expect(user_com_senha_temp).to be_valid
      end
    end
  end

  describe "escopos" do
    let!(:cliente_ativo)    { create(:user, :client, active: true) }
    let!(:cliente_inativo)  { create(:user, :client, active: false) }
    let!(:terapeuta)        { create(:user, :therapist, active: true) }

    describe ".clients" do
      it "retorna apenas usuários com role client" do
        expect(described_class.clients).to include(cliente_ativo, cliente_inativo)
        expect(described_class.clients).not_to include(terapeuta)
      end
    end

    describe ".active" do
      it "retorna apenas usuários ativos" do
        expect(described_class.active).to include(cliente_ativo, terapeuta)
        expect(described_class.active).not_to include(cliente_inativo)
      end
    end

    describe ".inactive" do
      it "retorna apenas usuários inativos" do
        expect(described_class.inactive).to include(cliente_inativo)
        expect(described_class.inactive).not_to include(cliente_ativo, terapeuta)
      end
    end
  end

  describe "desativação de cliente" do
    include_context "com fuso de São Paulo"

    let(:cliente) { create(:user, :client, active: true) }

    let!(:sessao_futura) do
      create(:session,
        user: cliente,
        start_time: 1.week.from_now.beginning_of_hour,
        end_time: 1.week.from_now.beginning_of_hour + 50.minutes,
        status: :scheduled)
    end

    let!(:sessao_passada) do
      create(:session,
        user: cliente,
        start_time: 1.week.ago.beginning_of_hour,
        end_time: 1.week.ago.beginning_of_hour + 50.minutes,
        status: :completed)
    end

    context "quando active muda para false" do
      before { cliente.update!(active: false) }

      it "cancela sessões futuras agendadas" do
        expect(sessao_futura.reload.status).to eq("cancelled")
      end

      it "preserva o histórico de sessões passadas" do
        expect(sessao_passada.reload.status).to eq("completed")
      end
    end

    context "quando cliente permanece ativo" do
      it "não altera sessões futuras" do
        expect { cliente.update!(name: "Nome Atualizado") }
          .not_to(change { sessao_futura.reload.status })
      end
    end
  end

  describe "audit trail" do
    include_context "com fuso de São Paulo"

    let(:performing_user) { create(:user, :therapist) }

    before { Current.user = performing_user }
    after  { Current.user = nil }

    context "quando cliente é desativado" do
      let(:cliente) { create(:user, :client, active: true) }

      it "registra um AuditLog" do
        expect { cliente.update!(active: false) }
          .to change(AuditLog, :count).by(1)
      end

      it "registra action 'deactivate' e entity correto" do
        cliente.update!(active: false)
        log = AuditLog.last
        expect(log.action).to eq("deactivate")
        expect(log.entity_type).to eq("User")
        expect(log.entity_id).to eq(cliente.id)
      end
    end
  end
end
