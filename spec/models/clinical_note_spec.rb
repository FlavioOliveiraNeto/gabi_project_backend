require 'rails_helper'

RSpec.describe ClinicalNote, type: :model do
  let(:therapist) { create(:user, :therapist) }
  let(:patient)   { create(:user, :client, therapist: therapist) }

  # Associações
  describe "associações" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:therapist).class_name("User") }
  end

  # Validações
  describe "validações" do
    subject(:note) { build(:clinical_note, user: patient, therapist: therapist) }

    it { is_expected.to validate_presence_of(:content) }

    it "é inválido com conteúdo acima de 10.000 caracteres" do
      note.content = "a" * 10_001
      expect(note).not_to be_valid
      expect(note.errors[:content]).to be_present
    end

    it "é válido com exatamente 10.000 caracteres" do
      note.content = "a" * 10_000
      expect(note).to be_valid
    end

    it "é inválido sem paciente" do
      note.user = nil
      expect(note).not_to be_valid
      expect(note.errors[:user]).to be_present
    end

    it "é inválido sem terapeuta" do
      note.therapist = nil
      expect(note).not_to be_valid
      expect(note.errors[:therapist]).to be_present
    end
  end

  # Criptografia
  describe "criptografia de conteúdo" do
    it "persiste e recupera o conteúdo corretamente" do
      original = "Paciente apresentou progresso significativo."
      note = create(:clinical_note, user: patient, therapist: therapist, content: original)
      expect(note.reload.content).to eq(original)
    end

    it "armazena o conteúdo criptografado no banco" do
      note = create(:clinical_note, user: patient, therapist: therapist, content: "Conteúdo secreto")
      raw = ActiveRecord::Base.connection.execute(
        "SELECT content FROM clinical_notes WHERE id = #{note.id}"
      ).first["content"]

      expect(raw).not_to eq("Conteúdo secreto")
    end
  end

  # Isolamento por terapeuta
  describe "isolamento por terapeuta" do
    let(:other_therapist) { create(:user, :therapist) }

    it "isola notas de terapeutas distintos para o mesmo paciente" do
      note1 = create(:clinical_note, user: patient, therapist: therapist)
      note2 = create(:clinical_note, user: patient, therapist: other_therapist)

      expect(patient.clinical_notes.where(therapist: therapist)).to contain_exactly(note1)
      expect(patient.clinical_notes.where(therapist: other_therapist)).to contain_exactly(note2)
    end
  end
end
