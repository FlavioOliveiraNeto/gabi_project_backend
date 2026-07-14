require 'rails_helper'

RSpec.describe SessionGeneratorService do
  let(:therapist) { create(:user, :therapist) }
  let(:patient)   { create(:user, :client, therapist: therapist) }
  let(:service)   { described_class.new(therapist) }

  # #generate_for_patient
  describe "#generate_for_patient" do
    context "com schedule ativo cobrindo toda a janela" do
      let!(:schedule) do
        create(:weekly_schedule, :monday, user: patient,
               time: "10:00", effective_from: 1.month.ago.to_date, effective_until: nil)
      end

      around(:each) { |e| travel_to(Time.zone.local(2026, 3, 1)) { e.run } }

      before { service.generate_for_patient(patient) }

      it "gera exatamente 9 sessões (5 segundas em março + 4 em abril)" do
        expect(patient.sessions.where(session_type: :recurring).count).to eq(9)
      end

      it "gera sessões somente nas segundas-feiras" do
        sessions = patient.sessions.where(session_type: :recurring).to_a
        expect(sessions).not_to be_empty
        expect(sessions.map { |s| s.scheduled_at.wday }).to all(eq(1))
      end

      it "gera sessões com horário 10:00" do
        sessions = patient.sessions.where(session_type: :recurring).to_a
        expect(sessions).not_to be_empty
        expect(sessions.map { |s| s.scheduled_at.strftime("%H:%M") }).to all(eq("10:00"))
      end

      it "não gera sessões para datas passadas" do
        expect(patient.sessions.where("scheduled_at < ?", Date.current.beginning_of_day)).to be_empty
      end

      it "não gera sessões além do fim do próximo mês" do
        expect(patient.sessions.where("scheduled_at > ?", Date.current.next_month.end_of_month.end_of_day)).to be_empty
      end

      it "é idempotente — não duplica sessões em chamadas consecutivas" do
        expect { service.generate_for_patient(patient) }.not_to change(Session, :count)
      end
    end

    context "com effective_until no meio da janela" do
      let!(:schedule) do
        create(:weekly_schedule, :monday, user: patient,
               time: "10:00",
               effective_from:  Date.new(2026, 3, 1),
               effective_until: Date.new(2026, 3, 15))
      end

      it "não gera sessões após effective_until" do
        travel_to Time.zone.local(2026, 3, 1) do
          service.generate_for_patient(patient)

          expect(patient.sessions.where("scheduled_at > ?", Date.new(2026, 3, 15).end_of_day)).to be_empty
        end
      end
    end

    context "com effective_from no futuro (dentro da janela)" do
      let!(:schedule) do
        create(:weekly_schedule, :monday, user: patient,
               time: "10:00",
               effective_from: Date.new(2026, 4, 1))
      end

      it "não gera sessões antes de effective_from" do
        travel_to Time.zone.local(2026, 3, 1) do
          service.generate_for_patient(patient)

          expect(patient.sessions.where("scheduled_at < ?", Date.new(2026, 4, 1))).to be_empty
        end
      end
    end

    context "com schedule expirado (fora da janela de geração)" do
      let!(:schedule) { create(:weekly_schedule, :expired, user: patient) }

      it "não gera nenhuma sessão" do
        expect { service.generate_for_patient(patient) }.not_to change(Session, :count)
      end
    end

    context "sem weekly_schedules" do
      it "não gera nenhuma sessão" do
        expect { service.generate_for_patient(patient) }.not_to change(Session, :count)
      end
    end

    context "com schedule sem horário definido (time blank)" do
      # update_column bypassa validações; testa o guard `return if schedule.time.blank?`
      let!(:schedule) do
        create(:weekly_schedule, :monday, user: patient,
               effective_from: 1.month.ago.to_date).tap do |s|
          s.update_column(:time, nil)
        end
      end

      it "não gera nenhuma sessão" do
        expect { service.generate_for_patient(patient) }.not_to change(Session, :count)
      end
    end

    context "com conflito de horário com outro paciente do mesmo terapeuta" do
      let(:patient_b) { create(:user, :client, therapist: therapist) }

      let!(:schedule) do
        create(:weekly_schedule, :monday, user: patient,
               time: "10:00", effective_from: Date.new(2026, 1, 1))
      end

      around(:each) { |e| travel_to(Time.zone.local(2026, 3, 1)) { e.run } }

      before do
        # Sessão de patient_b às 10:30 → cai no intervalo 09:00-11:00 de patient às 10:00
        create(:session, :scheduled, user: patient_b,
               scheduled_at: Time.zone.local(2026, 3, 2, 10, 30))
      end

      it "não levanta exceção ao encontrar conflito" do
        expect { service.generate_for_patient(patient) }.not_to raise_error
      end

      it "registra warning no log para cada sessão conflitante" do
        expect(Rails.logger).to receive(:warn).with(/Conflito ignorado/).at_least(:once)
        service.generate_for_patient(patient)
      end
    end
  end

  # #generate_for_patient_from
  describe "#generate_for_patient_from" do
    let!(:schedule) do
      create(:weekly_schedule, :monday, user: patient,
             time: "10:00", effective_from: Date.new(2026, 1, 1))
    end

    around(:each) { |e| travel_to(Time.zone.local(2026, 3, 1)) { e.run } }

    it "gera apenas sessões a partir de from" do
      from_date = Date.new(2026, 3, 16)
      service.generate_for_patient_from(patient, from: from_date)

      expect(patient.sessions.where("scheduled_at < ?", from_date.beginning_of_day)).to be_empty
    end

    it "respeita effective_until do schedule" do
      schedule.update!(effective_until: Date.new(2026, 3, 20))
      service.generate_for_patient_from(patient, from: Date.new(2026, 3, 16))

      expect(patient.sessions.where("scheduled_at > ?", Date.new(2026, 3, 20).end_of_day)).to be_empty
    end

    it "é idempotente" do
      service.generate_for_patient_from(patient, from: Date.current)
      count_after_first = Session.count

      service.generate_for_patient_from(patient, from: Date.current)
      expect(Session.count).to eq(count_after_first)
    end

    context "quando from está além do fim do próximo mês" do
      it "não gera nenhuma sessão" do
        from_date = Date.current.next_month.end_of_month + 1.day
        expect { service.generate_for_patient_from(patient, from: from_date) }.not_to change(Session, :count)
      end
    end

    context "quando o schedule começa após from" do
      let!(:late_schedule) do
        create(:weekly_schedule, :friday, user: patient,
               time: "14:00", effective_from: Date.new(2026, 4, 1))
      end

      it "gera sessões de sexta a partir de effective_from do schedule, não de from" do
        service.generate_for_patient_from(patient, from: Date.new(2026, 3, 1))

        friday_sessions = patient.sessions
          .where(session_type: :recurring)
          .select { |s| s.scheduled_at.wday == 5 }

        expect(friday_sessions).not_to be_empty
        expect(friday_sessions.map { |s| s.scheduled_at.to_date }).to all(be >= Date.new(2026, 4, 1))
      end
    end
  end

  # #generate_for_current_and_next_month
  describe "#generate_for_current_and_next_month" do
    context "com múltiplos pacientes com schedules ativos" do
      let(:patient_b) { create(:user, :client, therapist: therapist) }

      before do
        create(:weekly_schedule, :monday,  user: patient,   time: "09:00", effective_from: Date.new(2026, 1, 1))
        create(:weekly_schedule, :tuesday, user: patient_b, time: "11:00", effective_from: Date.new(2026, 1, 1))
      end

      it "gera sessões para todos os pacientes do terapeuta" do
        travel_to Time.zone.local(2026, 3, 1) do
          service.generate_for_current_and_next_month

          expect(patient.sessions.where(session_type: :recurring)).to exist
          expect(patient_b.sessions.where(session_type: :recurring)).to exist
        end
      end
    end

    context "com pacientes de outro terapeuta" do
      let(:other_therapist) { create(:user, :therapist) }
      let(:other_patient)   { create(:user, :client, therapist: other_therapist) }

      before do
        create(:weekly_schedule, :wednesday, user: other_patient,
               time: "10:00", effective_from: 1.month.ago.to_date)
      end

      it "não gera sessões para pacientes de outro terapeuta" do
        travel_to Time.zone.local(2026, 3, 1) do
          service.generate_for_current_and_next_month
          expect(other_patient.sessions).to be_empty
        end
      end
    end

    context "sem pacientes cadastrados" do
      it "não gera nenhuma sessão" do
        expect { service.generate_for_current_and_next_month }.not_to change(Session, :count)
      end
    end
  end
end
