require 'rails_helper'

RSpec.describe User, type: :model do
  # ─── Associações ────────────────────────────────────────────────────────────
  describe "associações" do
    it { is_expected.to belong_to(:therapist).class_name("User").optional }
    it { is_expected.to have_many(:patients).class_name("User").with_foreign_key("therapist_id").dependent(:destroy) }
    it { is_expected.to have_many(:sessions).dependent(:destroy) }
    it { is_expected.to have_many(:clinical_notes).dependent(:destroy) }
    it { is_expected.to have_many(:patient_notes).dependent(:destroy) }
    it { is_expected.to have_many(:weekly_schedules).dependent(:destroy) }
  end

  # ─── Enums ──────────────────────────────────────────────────────────────────
  describe "enums" do
    it { is_expected.to define_enum_for(:role).with_values(therapist: 0, client: 1) }
  end

  # ─── Validações ─────────────────────────────────────────────────────────────
  describe "validações" do
    it "é válido com dados mínimos" do
      expect(build(:user, :therapist)).to be_valid
    end

    describe "google_meet_link" do
      it "é válido com URL http" do
        expect(build(:user, google_meet_link: "http://meet.google.com/abc")).to be_valid
      end

      it "é válido com URL https" do
        expect(build(:user, google_meet_link: "https://meet.google.com/abc")).to be_valid
      end

      it "é válido quando em branco" do
        expect(build(:user, google_meet_link: "")).to be_valid
        expect(build(:user, google_meet_link: nil)).to be_valid
      end

      it "é inválido sem http:// ou https://" do
        user = build(:user, google_meet_link: "meet.google.com/abc")
        expect(user).not_to be_valid
        expect(user.errors[:google_meet_link]).to be_present
      end
    end

    describe "email" do
      it "é inválido sem email" do
        user = build(:user, email: "")
        expect(user).not_to be_valid
      end

      it "é inválido com email duplicado" do
        create(:user, email: "dup@example.com")
        expect(build(:user, email: "dup@example.com")).not_to be_valid
      end
    end
  end

  # ─── Roles ──────────────────────────────────────────────────────────────────
  describe "roles" do
    it "identifica corretamente um terapeuta" do
      expect(build(:user, :therapist).therapist?).to be true
      expect(build(:user, :therapist).client?).to be false
    end

    it "identifica corretamente um cliente" do
      expect(build(:user, :client).client?).to be true
      expect(build(:user, :client).therapist?).to be false
    end
  end

  # ─── Métodos de instância ───────────────────────────────────────────────────
  describe "#must_change_password?" do
    it "retorna true quando must_change_password é true" do
      user = build(:user, must_change_password: true)
      expect(user.must_change_password?).to be true
    end

    it "retorna false quando must_change_password é false" do
      user = build(:user, must_change_password: false)
      expect(user.must_change_password?).to be false
    end
  end

  describe "#clear_must_change_password!" do
    it "define must_change_password como false no banco" do
      user = create(:user, must_change_password: true)
      user.clear_must_change_password!
      expect(user.reload.must_change_password).to be false
    end
  end

  # ─── Destruição em cascata ──────────────────────────────────────────────────
  describe "destruição em cascata" do
    let(:therapist) { create(:user, :therapist) }
    let!(:patient)  { create(:user, :client, therapist: therapist) }

    it "destrói os pacientes ao destruir o terapeuta" do
      expect { therapist.destroy }.to change(User, :count).by(-2)
    end

    it "destrói as sessões ao destruir o paciente" do
      create(:session, user: patient)
      expect { patient.destroy }.to change(Session, :count).by(-1)
    end

    it "destrói os weekly_schedules ao destruir o paciente" do
      create(:weekly_schedule, user: patient)
      expect { patient.destroy }.to change(WeeklySchedule, :count).by(-1)
    end

    it "destrói as clinical_notes ao destruir o paciente" do
      create(:clinical_note, user: patient, therapist: therapist)
      expect { patient.destroy }.to change(ClinicalNote, :count).by(-1)
    end

    it "destrói as patient_notes ao destruir o usuário" do
      create(:patient_note, user: patient)
      expect { patient.destroy }.to change(PatientNote, :count).by(-1)
    end
  end
end
