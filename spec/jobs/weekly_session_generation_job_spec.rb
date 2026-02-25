require 'rails_helper'

RSpec.describe WeeklySessionGenerationJob, type: :job do
  let(:therapist)  { create(:user, :therapist) }
  let(:patient)    { create(:user, :client, therapist: therapist) }

  describe "#perform" do
    context "terapeuta com pacientes e agendas ativas" do
      before do
        create(:weekly_schedule, :monday, user: patient,
               time: "10:00", effective_from: 1.month.ago.to_date)
      end

      it "gera sessões para o paciente" do
        travel_to Time.zone.local(2026, 3, 1) do
          expect {
            described_class.new.perform
          }.to change(Session, :count).by_at_least(1)
        end
      end

      it "gera sessões apenas para o mês atual e próximo" do
        travel_to Time.zone.local(2026, 3, 1) do
          described_class.new.perform

          sessions = patient.sessions.where(session_type: :regular)
          sessions.each do |s|
            expect(s.scheduled_at.to_date).to be >= Date.new(2026, 3, 1)
            expect(s.scheduled_at.to_date).to be <= Date.new(2026, 4, 30)
          end
        end
      end
    end

    context "múltiplos terapeutas" do
      let(:other_therapist) { create(:user, :therapist) }
      let(:other_patient)   { create(:user, :client, therapist: other_therapist) }

      before do
        create(:weekly_schedule, :monday,  user: patient,       time: "09:00", effective_from: 1.month.ago.to_date)
        create(:weekly_schedule, :tuesday, user: other_patient, time: "11:00", effective_from: 1.month.ago.to_date)
      end

      it "gera sessões para todos os terapeutas" do
        travel_to Time.zone.local(2026, 3, 1) do
          described_class.new.perform

          expect(patient.sessions.where(session_type: :regular)).to exist
          expect(other_patient.sessions.where(session_type: :regular)).to exist
        end
      end
    end

    context "terapeuta sem pacientes" do
      let(:empty_therapist) { create(:user, :therapist) }

      it "não gera nenhuma sessão para esse terapeuta" do
        travel_to Time.zone.local(2026, 3, 1) do
          expect { described_class.new.perform }.not_to change(Session, :count)
        end
      end
    end

    context "idempotência" do
      before do
        create(:weekly_schedule, :monday, user: patient,
               time: "10:00", effective_from: 1.month.ago.to_date)
      end

      it "não duplica sessões ao rodar duas vezes" do
        travel_to Time.zone.local(2026, 3, 1) do
          described_class.new.perform
          count = Session.count

          described_class.new.perform
          expect(Session.count).to eq(count)
        end
      end
    end

    it "usa a fila :default" do
      expect(described_class.queue_name).to eq("default")
    end
  end
end
