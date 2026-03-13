# frozen_string_literal: true

require "rails_helper"

RSpec.describe AuditLog, type: :model do
  subject(:log) { build(:audit_log) }

  # ---------------------------------------------------------------------------
  # Validações
  # ---------------------------------------------------------------------------
  describe "validações" do
    context "com dados válidos" do
      it "é válido" do
        expect(log).to be_valid
      end
    end

    describe "presença de campos obrigatórios" do
      it "é inválido sem user" do
        log.user = nil
        expect(log).to be_invalid
        expect(log.errors[:user]).to be_present
      end

      it "é inválido sem action" do
        log.action = nil
        expect(log).to be_invalid
        expect(log.errors[:action]).to be_present
      end

      it "é inválido com action em branco" do
        log.action = "  "
        expect(log).to be_invalid
        expect(log.errors[:action]).to be_present
      end

      it "é inválido sem entity_type" do
        log.entity_type = nil
        expect(log).to be_invalid
        expect(log.errors[:entity_type]).to be_present
      end

      it "é inválido sem entity_id" do
        log.entity_id = nil
        expect(log).to be_invalid
        expect(log.errors[:entity_id]).to be_present
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Associações
  # ---------------------------------------------------------------------------
  describe "associações" do
    it { is_expected.to belong_to(:user) }
  end

  # ---------------------------------------------------------------------------
  # Imutabilidade (crítico)
  # ---------------------------------------------------------------------------
  describe "imutabilidade" do
    let(:log_criado) { create(:audit_log) }

    describe "update" do
      it "não pode ser atualizado após criação" do
        expect { log_criado.update!(action: "outro_action") }
          .to raise_error(ActiveRecord::ReadOnlyRecord)
      end

      it "update retorna false sem levanta erro quando chamado com update (sem bang)" do
        expect(log_criado.update(action: "outro_action")).to be_falsey
      end
    end

    describe "destroy" do
      it "não pode ser deletado" do
        expect { log_criado.destroy! }
          .to raise_error(ActiveRecord::ReadOnlyRecord)
      end

      it "não remove o registro do banco ao chamar destroy" do
        log_criado.destroy
        expect(described_class.exists?(log_criado.id)).to be true
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Escopos
  # ---------------------------------------------------------------------------
  describe "escopos" do
    let(:user1) { create(:user) }
    let(:user2) { create(:user) }

    let!(:log_session_1) { create(:audit_log, user: user1, entity_type: "Session",  entity_id: 10) }
    let!(:log_session_2) { create(:audit_log, user: user2, entity_type: "Session",  entity_id: 20) }
    let!(:log_user)      { create(:audit_log, user: user1, entity_type: "User",     entity_id: 10) }
    let!(:log_block)     { create(:audit_log, user: user2, entity_type: "CalendarBlock", entity_id: 5) }

    describe ".for_entity(type, id)" do
      it "filtra por entity_type e entity_id" do
        resultado = described_class.for_entity("Session", 10)
        expect(resultado).to include(log_session_1)
        expect(resultado).not_to include(log_session_2, log_user, log_block)
      end

      it "retorna vazio quando não há logs para a entidade" do
        expect(described_class.for_entity("Session", 9999)).to be_empty
      end
    end

    describe ".for_user(user)" do
      it "filtra por usuário" do
        resultado = described_class.for_user(user1)
        expect(resultado).to include(log_session_1, log_user)
        expect(resultado).not_to include(log_session_2, log_block)
      end
    end

    describe ".recent" do
      it "ordena por created_at desc" do
        ids_esperados = described_class.order(created_at: :desc).pluck(:id)
        ids_resultado = described_class.recent.pluck(:id)
        expect(ids_resultado).to eq(ids_esperados)
      end

      it "coloca o registro mais recente primeiro" do
        mais_recente = create(:audit_log, user: user1)
        expect(described_class.recent.first).to eq(mais_recente)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # metadata
  # ---------------------------------------------------------------------------
  describe "metadata (jsonb)" do
    it "armazena metadata como hash" do
      log = create(:audit_log, metadata: { ip: "127.0.0.1", user_agent: "RSpec" })
      expect(log.reload.metadata).to eq({ "ip" => "127.0.0.1", "user_agent" => "RSpec" })
    end

    it "é válido com metadata vazio" do
      log = build(:audit_log, metadata: {})
      expect(log).to be_valid
    end

    it "é válido sem metadata (nil)" do
      log = build(:audit_log, metadata: nil)
      expect(log).to be_valid
    end
  end
end
