require 'rails_helper'

RSpec.describe ClinicalNote, type: :model do
  let(:therapist) { create(:user, :therapist) }
  let(:patient)   { create(:user, :client, therapist: therapist) }

  # ─── Associações ────────────────────────────────────────────────────────────
  describe "associações" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:therapist).class_name("User") }
  end

  # ─── Validações ─────────────────────────────────────────────────────────────
  describe "validações" do
    it "é válido com conteúdo, paciente e terapeuta" do
      note = build(:clinical_note, user: patient, therapist: therapist)
      expect(note).to be_valid
    end

    it { is_expected.to validate_presence_of(:content) }

    it "é inválido sem conteúdo" do
      note = build(:clinical_note, user: patient, therapist: therapist, content: "")
      expect(note).not_to be_valid
      expect(note.errors[:content]).to be_present
    end

    it "é inválido com conteúdo acima de 10.000 caracteres" do
      note = build(:clinical_note, user: patient, therapist: therapist, content: "a" * 10_001)
      expect(note).not_to be_valid
      expect(note.errors[:content]).to be_present
    end

    it "é válido com exatamente 10.000 caracteres" do
      note = build(:clinical_note, user: patient, therapist: therapist, content: "a" * 10_000)
      expect(note).to be_valid
    end
  end

  # ─── Criptografia ───────────────────────────────────────────────────────────
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

      # O valor no banco deve ser diferente do plaintext (criptografado)
      expect(raw).not_to eq("Conteúdo secreto")
    end
  end

  # ─── Isolamento por terapeuta ────────────────────────────────────────────────
  describe "isolamento por terapeuta" do
    let(:other_therapist) { create(:user, :therapist) }

    it "permite criar notas de terapeutas diferentes para o mesmo paciente" do
      note1 = create(:clinical_note, user: patient, therapist: therapist)
      note2 = create(:clinical_note, user: patient, therapist: other_therapist)

      expect(patient.clinical_notes.where(therapist: therapist)).to include(note1)
      expect(patient.clinical_notes.where(therapist: other_therapist)).to include(note2)
    end

    it "filtra notas por terapeuta corretamente" do
      create(:clinical_note, user: patient, therapist: therapist, content: "Nota do terapeuta A")
      create(:clinical_note, user: patient, therapist: other_therapist, content: "Nota do terapeuta B")

      notas_do_terapeuta = patient.clinical_notes.where(therapist: therapist)
      expect(notas_do_terapeuta.count).to eq(1)
      expect(notas_do_terapeuta.first.content).to eq("Nota do terapeuta A")
    end
  end
end
