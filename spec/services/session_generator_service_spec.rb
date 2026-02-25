require 'rails_helper'

RSpec.describe SessionGeneratorService do
  let(:therapist) { create(:user, :therapist) }
  let(:patient)   { create(:user, :client, therapist: therapist) }
  let(:service)   { described_class.new(therapist) }

  # ─────────────────────────────────────────────────────────────────
  # generate_for_patient
  # ─────────────────────────────────────────────────────────────────
  describe "#generate_for_patient" do
    context "schedule ativo cobrindo toda a janela" do
      let!(:schedule) do
        create(:weekly_schedule, :monday, user: patient,
               time: "10:00", effective_from: 1.month.ago.to_date, effective_until: nil)
      end

      it "gera sessões somente nas segundas-feiras" do
        travel_to Time.zone.local(2026, 3, 1) do
          service.generate_for_patient(patient)

          patient.sessions.where(session_type: :regular).each do |s|
            expect(s.scheduled_at.wday).to eq(1) # 1 = monday
          end
        end
      end

      it "gera com o horário correto" do
        travel_to Time.zone.local(2026, 3, 1) do
          service.generate_for_patient(patient)

          patient.sessions.where(session_type: :regular).each do |s|
            expect(s.scheduled_at.strftime("%H:%M")).to eq("10:00")
          end
        end
      end

      it "não gera sessões para datas passadas" do
        travel_to Time.zone.local(2026, 3, 15) do
          service.generate_for_patient(patient)

          past_sessions = patient.sessions.where("scheduled_at < ?", Date.current.beginning_of_day)
          expect(past_sessions).to be_empty
        end
      end

      it "é idempotente — não duplica sessões existentes" do
        travel_to Time.zone.local(2026, 3, 1) do
          service.generate_for_patient(patient)
          count_after_first = Session.count

          service.generate_for_patient(patient)
          expect(Session.count).to eq(count_after_first)
        end
      end
    end

    context "schedule com effective_until no meio da janela" do
      let!(:schedule) do
        create(:weekly_schedule, :monday, user: patient,
               time: "10:00",
               effective_from:  Date.new(2026, 3, 1),
               effective_until: Date.new(2026, 3, 15))
      end

      it "não gera sessões após effective_until" do
        travel_to Time.zone.local(2026, 3, 1) do
          service.generate_for_patient(patient)

          late = patient.sessions.where("scheduled_at > ?", Date.new(2026, 3, 15).end_of_day)
          expect(late).to be_empty
        end
      end
    end

    context "schedule com effective_from no futuro (dentro da janela)" do
      let!(:schedule) do
        create(:weekly_schedule, :monday, user: patient,
               time: "10:00",
               effective_from: Date.new(2026, 4, 1))
      end

      it "não gera sessões antes de effective_from" do
        travel_to Time.zone.local(2026, 3, 1) do
          service.generate_for_patient(patient)

          early = patient.sessions.where("scheduled_at < ?", Date.new(2026, 4, 1))
          expect(early).to be_empty
        end
      end
    end

    context "schedule expirado (fora da janela de geração)" do
      let!(:schedule) { create(:weekly_schedule, :expired, user: patient) }

      it "não gera nenhuma sessão" do
        expect { service.generate_for_patient(patient) }.not_to change(Session, :count)
      end
    end

    context "paciente sem weekly_schedules" do
      it "não gera nenhuma sessão" do
        expect { service.generate_for_patient(patient) }.not_to change(Session, :count)
      end
    end

    context "conflito de horário com outro paciente do mesmo terapeuta" do
      let(:patient_b) { create(:user, :client, therapist: therapist) }

      let!(:schedule) do
        create(:weekly_schedule, :monday, user: patient,
               time: "10:00", effective_from: 1.month.ago.to_date)
      end

      before do
        # Cria sessão de patient_b no mesmo horário (segunda às 10:30)
        travel_to Time.zone.local(2026, 3, 1) do
          create(:session, :scheduled, user: patient_b,
                 scheduled_at: Time.zone.local(2026, 3, 2, 10, 30)) # 30 min de diferença
        end
      end

      it "silencia o conflito sem levantar exceção" do
        travel_to Time.zone.local(2026, 3, 1) do
          expect { service.generate_for_patient(patient) }.not_to raise_error
        end
      end

      it "registra warning no log" do
        travel_to Time.zone.local(2026, 3, 1) do
          expect(Rails.logger).to receive(:warn).with(/Conflito ignorado/).at_least(:once)
          service.generate_for_patient(patient)
        end
      end
    end
  end

  # ─────────────────────────────────────────────────────────────────
  # generate_for_patient_from
  # ─────────────────────────────────────────────────────────────────
  describe "#generate_for_patient_from(patient, from:)" do
    let!(:schedule) do
      create(:weekly_schedule, :monday, user: patient,
             time: "10:00", effective_from: 1.month.ago.to_date)
    end

    it "gera apenas sessões a partir da data informada" do
      travel_to Time.zone.local(2026, 3, 1) do
        from_date = Date.new(2026, 3, 16)
        service.generate_for_patient_from(patient, from: from_date)

        early = patient.sessions.where("scheduled_at < ?", from_date.beginning_of_day)
        expect(early).to be_empty
      end
    end

    it "respeita effective_until do schedule" do
      schedule.update!(effective_until: Date.new(2026, 3, 20))

      travel_to Time.zone.local(2026, 3, 1) do
        service.generate_for_patient_from(patient, from: Date.new(2026, 3, 16))

        late = patient.sessions.where("scheduled_at > ?", Date.new(2026, 3, 20).end_of_day)
        expect(late).to be_empty
      end
    end

    it "é idempotente" do
      travel_to Time.zone.local(2026, 3, 1) do
        service.generate_for_patient_from(patient, from: Date.current)
        count_after_first = Session.count

        service.generate_for_patient_from(patient, from: Date.current)
        expect(Session.count).to eq(count_after_first)
      end
    end

    context "quando o schedule começa após from" do
      let!(:late_schedule) do
        create(:weekly_schedule, :friday, user: patient,
               time: "14:00", effective_from: Date.new(2026, 4, 1))
      end

      it "gera a partir do effective_from do schedule, não do from" do
        travel_to Time.zone.local(2026, 3, 1) do
          service.generate_for_patient_from(patient, from: Date.new(2026, 3, 1))

          friday_sessions = patient.sessions.where(session_type: :regular).select do |s|
            s.scheduled_at.wday == 5 # friday
          end

          friday_sessions.each do |s|
            expect(s.scheduled_at.to_date).to be >= Date.new(2026, 4, 1)
          end
        end
      end
    end
  end

  # ─────────────────────────────────────────────────────────────────
  # generate_for_current_and_next_month
  # ─────────────────────────────────────────────────────────────────
  describe "#generate_for_current_and_next_month" do
    let(:patient_b) { create(:user, :client, therapist: therapist) }

    before do
      create(:weekly_schedule, :monday, user: patient,
             time: "09:00", effective_from: 1.month.ago.to_date)
      create(:weekly_schedule, :tuesday, user: patient_b,
             time: "11:00", effective_from: 1.month.ago.to_date)
    end

    it "gera sessões para todos os pacientes do terapeuta" do
      travel_to Time.zone.local(2026, 3, 1) do
        service.generate_for_current_and_next_month

        expect(patient.sessions.where(session_type: :regular)).to exist
        expect(patient_b.sessions.where(session_type: :regular)).to exist
      end
    end

    it "não gera sessões para pacientes de outro terapeuta" do
      other_therapist = create(:user, :therapist)
      other_patient   = create(:user, :client, therapist: other_therapist)
      create(:weekly_schedule, :wednesday, user: other_patient,
             time: "10:00", effective_from: 1.month.ago.to_date)

      travel_to Time.zone.local(2026, 3, 1) do
        service.generate_for_current_and_next_month
        expect(other_patient.sessions).to be_empty
      end
    end
  end
end
