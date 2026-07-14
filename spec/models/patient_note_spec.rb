require 'rails_helper'

RSpec.describe PatientNote, type: :model do
  let(:patient) { create(:user, :client) }

  # Associações
  describe "associações" do
    it { is_expected.to belong_to(:user) }
  end

  # Validações
  describe "validações" do
    it { is_expected.to validate_presence_of(:content) }
    it { is_expected.to validate_length_of(:content).is_at_most(10_000) }

    it "é inválido com conteúdo acima de 10.000 caracteres" do
      note = build(:patient_note, user: patient, content: "a" * 10_001)
      expect(note).not_to be_valid
      expect(note.errors[:content]).to be_present
    end

    it "é válido com exatamente 10.000 caracteres" do
      note = build(:patient_note, user: patient, content: "a" * 10_000)
      expect(note).to be_valid
    end
  end

  # Criptografia
  describe "criptografia de conteúdo" do
    it "persiste e recupera o conteúdo corretamente" do
      original = "Minha anotação pessoal sobre a sessão de hoje."
      note = create(:patient_note, user: patient, content: original)
      expect(note.reload.content).to eq(original)
    end

    it "armazena o conteúdo criptografado no banco" do
      note = create(:patient_note, user: patient, content: "Texto privado")
      raw = ActiveRecord::Base.connection.execute(
        "SELECT content FROM patient_notes WHERE id = #{note.id}"
      ).first["content"]

      expect(raw).not_to eq("Texto privado")
    end
  end

  # Isolamento por usuário
  describe "isolamento por usuário" do
    let(:other_patient) { create(:user, :client) }

    it "pertence apenas ao usuário que criou" do
      note = create(:patient_note, user: patient)
      expect(patient.patient_notes).to include(note)
      expect(other_patient.patient_notes).not_to include(note)
    end
  end
end
