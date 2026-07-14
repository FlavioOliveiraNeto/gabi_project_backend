# frozen_string_literal: true

require "rails_helper"

RSpec.describe ClinicalNote, type: :model do
  subject(:note) { build(:clinical_note) }

  # ---------------------------------------------------------------------------
  # Validações
  # ---------------------------------------------------------------------------
  describe "validações" do
    context "com dados válidos" do
      it "é válida" do
        expect(note).to be_valid
      end
    end

    describe "presença de campos obrigatórios" do
      it "é inválida sem user" do
        note.user = nil
        expect(note).to be_invalid
        expect(note.errors[:user]).to be_present
      end

      it "é inválida sem session" do
        note.session = nil
        expect(note).to be_invalid
        expect(note.errors[:session]).to be_present
      end

      it "é inválida sem content" do
        note.content = nil
        expect(note).to be_invalid
        expect(note.errors[:content]).to be_present
      end

      it "é inválida com content em branco" do
        note.content = "  "
        expect(note).to be_invalid
        expect(note.errors[:content]).to be_present
      end
    end

    describe "unicidade de session_id" do
      it "é inválida quando já existe anotação para a mesma sessão" do
        cliente = create(:user, :client)
        sessao  = create(:session, :past, user: cliente)
        create(:clinical_note, session: sessao, user: cliente, content: "Primeira nota")
        duplicada = build(:clinical_note, session: sessao, user: cliente, content: "Segunda nota")

        expect(duplicada).to be_invalid
        expect(duplicada.errors[:session_id]).to be_present
      end

      it "é válida quando diferentes sessões têm suas próprias notas" do
        cliente = create(:user, :client)
        sessao1 = create(:session, :past, user: cliente)
        sessao2 = create(:session,
          user: cliente,
          start_time: 2.weeks.ago.beginning_of_hour,
          end_time: 2.weeks.ago.beginning_of_hour + 50.minutes,
          status: :completed)

        create(:clinical_note, session: sessao1, user: cliente)
        nota2 = build(:clinical_note, session: sessao2, user: cliente)
        expect(nota2).to be_valid
      end
    end

    describe "consistência entre user_id e session" do
      it "é inválida quando user_id não corresponde ao user da sessão" do
        usuario_da_sessao = create(:user, :client)
        usuario_diferente = create(:user, :client)
        sessao = create(:session, :past, user: usuario_da_sessao)

        nota = build(:clinical_note, session: sessao, user: usuario_diferente)
        expect(nota).to be_invalid
        expect(nota.errors[:user_id]).to be_present
      end

      it "é válida quando user_id corresponde ao user da sessão" do
        cliente = create(:user, :client)
        sessao  = create(:session, :past, user: cliente)
        nota    = build(:clinical_note, session: sessao, user: cliente)
        expect(nota).to be_valid
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Associações
  # ---------------------------------------------------------------------------
  describe "associações" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:session) }
  end

  # ---------------------------------------------------------------------------
  # Criptografia do conteúdo
  # ---------------------------------------------------------------------------
  describe "criptografia do conteúdo" do
    let(:conteudo_original) { "Paciente apresentou melhora significativa no manejo da ansiedade." }
    let(:nota) { create(:clinical_note, content: conteudo_original) }

    it "retorna o conteúdo legível (descriptografado) pelo model" do
      expect(nota.content).to eq(conteudo_original)
    end

    it "o valor armazenado diretamente no banco é diferente do conteúdo original" do
      raw = ActiveRecord::Base.connection.execute(
        "SELECT content FROM clinical_notes WHERE id = #{nota.id}"
      ).first["content"]

      expect(raw).not_to eq(conteudo_original)
      expect(raw).to be_present
    end

    it "o valor raw no banco não contém o conteúdo original em texto claro" do
      raw = ActiveRecord::Base.connection.execute(
        "SELECT content FROM clinical_notes WHERE id = #{nota.id}"
      ).first["content"]

      expect(raw).not_to include(conteudo_original)
    end

    it "duas notas com mesmo conteúdo têm valores criptografados diferentes (IV aleatório)" do
      cliente = create(:user, :client)
      sessao1 = create(:session, :past, user: cliente)
      sessao2 = create(:session,
        user: cliente,
        start_time: 2.weeks.ago.beginning_of_hour,
        end_time: 2.weeks.ago.beginning_of_hour + 50.minutes,
        status: :completed)

      nota1 = create(:clinical_note, session: sessao1, user: cliente, content: conteudo_original)
      nota2 = create(:clinical_note, session: sessao2, user: cliente, content: conteudo_original)

      raw1 = ActiveRecord::Base.connection.execute(
        "SELECT content FROM clinical_notes WHERE id = #{nota1.id}"
      ).first["content"]

      raw2 = ActiveRecord::Base.connection.execute(
        "SELECT content FROM clinical_notes WHERE id = #{nota2.id}"
      ).first["content"]

      expect(raw1).not_to eq(raw2)
    end

    it "ao atualizar o conteúdo, o valor criptografado é atualizado" do
      raw_antes = ActiveRecord::Base.connection.execute(
        "SELECT content FROM clinical_notes WHERE id = #{nota.id}"
      ).first["content"]

      nota.update!(content: "Novo conteúdo clínico após reavaliação.")

      raw_depois = ActiveRecord::Base.connection.execute(
        "SELECT content FROM clinical_notes WHERE id = #{nota.id}"
      ).first["content"]

      expect(raw_depois).not_to eq(raw_antes)
      expect(nota.reload.content).to eq("Novo conteúdo clínico após reavaliação.")
    end
  end
end
