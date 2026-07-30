require 'rails_helper'

RSpec.describe "Constraints de slot em sessions", type: :model do
  let(:therapist) { create(:user, :therapist) }
  let(:patient)   { create(:user, :client, therapist: therapist) }
  let(:other_patient) { create(:user, :client, therapist: therapist) }
  let(:slot)      { 1.week.from_now.beginning_of_hour }

  describe "desnormalização de therapist_id" do
    it "preenche therapist_id a partir do dono da sessão" do
      session = create(:session, user: patient, start_time: slot, end_time: slot + 50.minutes)

      expect(session.therapist_id).to eq(therapist.id)
    end

    it "mantém sincronizado quando o paciente troca de terapeuta" do
      session = create(:session, user: patient, start_time: slot, end_time: slot + 50.minutes)
      new_therapist = create(:user, :therapist)
      patient.update!(therapist: new_therapist)

      session.reload.save!

      expect(session.reload.therapist_id).to eq(new_therapist.id)
    end

    it "aceita nil quando o paciente não tem terapeuta" do
      orphan  = create(:user, :client, therapist: nil)
      session = create(:session, user: orphan, start_time: slot, end_time: slot + 50.minutes)

      expect(session.therapist_id).to be_nil
    end
  end

  describe "índice único (user_id, scheduled_at, session_type)" do
    it "impede duas sessões idênticas para o mesmo paciente mesmo driblando a validação" do
      create(:session, user: patient, scheduled_at: slot, start_time: slot, end_time: slot + 50.minutes)

      expect {
        Session.insert_all!([ {
          user_id: patient.id, therapist_id: therapist.id,
          scheduled_at: slot, start_time: slot, end_time: slot + 50.minutes,
          status: Session.statuses[:scheduled], session_type: Session.session_types[:recurring],
          created_at: Time.current, updated_at: Time.current
        } ])
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "permite mesmo horário com session_type diferente" do
      create(:session, user: patient, scheduled_at: slot, start_time: slot, end_time: slot + 50.minutes)

      duplicate = build(:session, :extra, user: patient, scheduled_at: slot,
                        start_time: slot, end_time: slot + 50.minutes, status: :cancelled)

      expect { duplicate.save!(validate: false) }.not_to raise_error
    end
  end

  describe "índice único parcial (therapist_id, start_time) WHERE status = 0" do
    it "impede dois pacientes agendados no mesmo slot da terapeuta" do
      create(:session, user: patient, scheduled_at: slot, start_time: slot, end_time: slot + 50.minutes)

      expect {
        Session.insert_all!([ {
          user_id: other_patient.id, therapist_id: therapist.id,
          scheduled_at: slot + 1.second, start_time: slot, end_time: slot + 50.minutes,
          status: Session.statuses[:scheduled], session_type: Session.session_types[:recurring],
          created_at: Time.current, updated_at: Time.current
        } ])
      }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "libera o slot quando a sessão anterior é cancelada" do
      first = create(:session, user: patient, scheduled_at: slot, start_time: slot, end_time: slot + 50.minutes)
      first.cancel!

      replacement = build(:session, user: other_patient, scheduled_at: slot,
                          start_time: slot, end_time: slot + 50.minutes)

      expect(replacement.save).to be true
    end

    it "não restringe sessões de terapeutas diferentes" do
      create(:session, user: patient, scheduled_at: slot, start_time: slot, end_time: slot + 50.minutes)
      unrelated = create(:user, :client, therapist: create(:user, :therapist))

      other = build(:session, user: unrelated, scheduled_at: slot,
                    start_time: slot, end_time: slot + 50.minutes)

      expect(other.save).to be true
    end

    it "não restringe sessões concluídas no mesmo horário (histórico)" do
      past = 2.weeks.ago.beginning_of_hour
      create(:session, user: patient, scheduled_at: past, start_time: past,
             end_time: past + 50.minutes, status: :completed)

      historical = build(:session, user: other_patient, scheduled_at: past,
                         start_time: past, end_time: past + 50.minutes, status: :completed)

      expect { historical.save!(validate: false) }.not_to raise_error
    end
  end

  describe "validação em Ruby continua ativa" do
    it "rejeita conflito antes de chegar ao banco, com mensagem de negócio" do
      create(:session, user: patient, scheduled_at: slot, start_time: slot, end_time: slot + 50.minutes)

      conflicting = build(:session, user: other_patient, scheduled_at: slot,
                          start_time: slot, end_time: slot + 50.minutes)

      expect(conflicting).to be_invalid
      expect(conflicting.errors[:start_time].join).to match(/conflita/)
    end

    it "cobre sobreposição parcial, que o índice de igualdade não pega" do
      create(:session, user: patient, scheduled_at: slot, start_time: slot, end_time: slot + 50.minutes)

      overlapping = build(:session, user: other_patient,
                          scheduled_at: slot + 30.minutes,
                          start_time: slot + 30.minutes,
                          end_time: slot + 80.minutes)

      expect(overlapping).to be_invalid
    end
  end
end
