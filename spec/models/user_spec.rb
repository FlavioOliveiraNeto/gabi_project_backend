# frozen_string_literal: true

require "rails_helper"

RSpec.describe User, type: :model do
  subject(:user) { build(:user) }

  # ---------------------------------------------------------------------------
  # Validações
  # ---------------------------------------------------------------------------
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
      it "é inválido com senha menor que 8 caracteres" do
        user.password = "abc123"
        expect(user).to be_invalid
        expect(user.errors[:password]).to be_present
      end

      it "é válido com senha de exatamente 8 caracteres" do
        user.password = "Senha@12"
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
  end

  # ---------------------------------------------------------------------------
  # Associações
  # ---------------------------------------------------------------------------
  describe "associações" do
    it { is_expected.to have_many(:audit_logs) }
    it { is_expected.to have_many(:sessions) }
    it { is_expected.to have_many(:recurring_schedules) }
  end

  # ---------------------------------------------------------------------------
  # Métodos de instância
  # ---------------------------------------------------------------------------
  describe "#therapist?" do
    context "when role é therapist" do
      let(:user) { build(:user, :therapist) }

      it "retorna true" do
        expect(user.therapist?).to be true
      end
    end

    context "when role é client" do
      let(:user) { build(:user, :client) }

      it "retorna false" do
        expect(user.therapist?).to be false
      end
    end
  end

  describe "#client?" do
    context "when role é client" do
      let(:user) { build(:user, :client) }

      it "retorna true" do
        expect(user.client?).to be true
      end
    end

    context "when role é therapist" do
      let(:user) { build(:user, :therapist) }

      it "retorna false" do
        expect(user.client?).to be false
      end
    end
  end

  describe "#force_password_change?" do
    context "when force_password_change é false" do
      let(:user) { build(:user, force_password_change: false) }

      it "retorna false" do
        expect(user.force_password_change?).to be false
      end
    end

    context "when force_password_change é true" do
      let(:user) { build(:user, :with_force_password_change) }

      it "retorna true" do
        expect(user.force_password_change?).to be true
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Segurança — armazenamento da senha
  # ---------------------------------------------------------------------------
  describe "segurança da senha" do
    let(:user) { create(:user, password: "Senha@123!") }

    it "não armazena a senha em texto plano" do
      expect(user.encrypted_password).not_to eq("Senha@123!")
    end

    it "armazena a senha como hash bcrypt (começa com $2)" do
      expect(user.encrypted_password).to start_with("$2")
    end

    it "dois usuários com a mesma senha têm encrypted_password diferentes (salt único)" do
      outro = create(:user, password: "Senha@123!")
      expect(user.encrypted_password).not_to eq(outro.encrypted_password)
    end
  end

  # ---------------------------------------------------------------------------
  # Normalização do email
  # ---------------------------------------------------------------------------
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

  # ---------------------------------------------------------------------------
  # Valores padrão
  # ---------------------------------------------------------------------------
  describe "valores padrão" do
    let(:novo_usuario) { described_class.new }

    it "force_password_change começa como false" do
      expect(novo_usuario.force_password_change).to be false
    end

    it "active começa como true" do
      expect(novo_usuario.active).to be true
    end
  end

  # ---------------------------------------------------------------------------
  # Senha temporária — cadastro pela terapeuta
  # ---------------------------------------------------------------------------
  describe "senha temporária (criado pela terapeuta)" do
    context "when criado sem force_password_change explícito" do
      it "force_password_change é false por padrão" do
        user = build(:user)
        expect(user.force_password_change).to be false
      end
    end

    context "when criado com force_password_change: true" do
      let(:user_com_senha_temp) { build(:user, :with_force_password_change) }

      it "force_password_change é true" do
        expect(user_com_senha_temp.force_password_change).to be true
      end

      it "o usuário é válido mesmo com force_password_change true" do
        expect(user_com_senha_temp).to be_valid
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Escopos de clientes
  # ---------------------------------------------------------------------------
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

  # ---------------------------------------------------------------------------
  # Comportamento ao desativar cliente
  # ---------------------------------------------------------------------------
  describe "desativação de cliente" do
    include_context "with São Paulo timezone"

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

    context "when active muda para false" do
      before { cliente.update!(active: false) }

      it "cancela sessões futuras agendadas" do
        expect(sessao_futura.reload.status).to eq("cancelled")
      end

      it "preserva o histórico de sessões passadas" do
        expect(sessao_passada.reload.status).to eq("completed")
      end
    end

    context "when cliente permanece ativo" do
      it "não altera sessões futuras" do
        expect { cliente.update!(name: "Nome Atualizado") }
          .not_to(change { sessao_futura.reload.status })
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Audit trail
  # ---------------------------------------------------------------------------
  describe "audit trail" do
    include_context "with São Paulo timezone"

    let(:performing_user) { create(:user, :therapist) }

    before { Current.user = performing_user }
    after  { Current.user = nil }

    context "when cliente é desativado" do
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
