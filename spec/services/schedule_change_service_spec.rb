require 'rails_helper'

RSpec.describe ScheduleChangeService do
  let(:therapist) { create(:user, :therapist) }
  let(:patient)   { create(:user, :client, therapist: therapist) }

  def build_service(overrides = {})
    defaults = {
      patient:         patient,
      therapist:       therapist,
      effective_from:  Date.current,
      schedule_type:   "regular",
      schedule_params: {
        weekdays:          ["monday"],
        sessions_per_week: 1,
        session_time:      "10:00"
      }
    }
    described_class.new(**defaults.merge(overrides))
  end

  # TRANSIÇÃO PARA REGULAR
  describe "#call - schedule_type: 'regular'" do
    it "retorna o patient" do
      expect(build_service.call).to eq(patient)
    end

    context "paciente sem agenda prévia" do
      it "cria os weekly_schedules com effective_from correto" do
        effective_from = Date.current + 7.days
        build_service(effective_from: effective_from).call

        schedule = patient.weekly_schedules.last
        expect(schedule.weekday).to eq("monday")
        expect(schedule.effective_from).to eq(effective_from)
        expect(schedule.effective_until).to be_nil
      end

      it "gera sessões apenas a partir de effective_from" do
        travel_to Time.zone.local(2026, 3, 1) do
          effective_from = Date.new(2026, 3, 9) # próxima segunda

          build_service(
            effective_from:  effective_from,
            schedule_params: { weekdays: ["monday"], sessions_per_week: 1, session_time: "10:00" }
          ).call

          first_session = patient.sessions.where(session_type: :recurring).order(:scheduled_at).first
          expect(first_session.scheduled_at.to_date).to be >= effective_from
        end
      end
    end

    context "paciente com agenda ativa (mudando dias)" do
      let(:effective_from) { Date.current + 14.days }

      # Sessão ANTES da vigência (NÃO deve ser afetada)
      let!(:session_before) do
        create(:session, :scheduled, user: patient,
               scheduled_at: effective_from - 3.days)
      end

      # Sessão APÓS a vigência (DEVE ser cancelada)
      let!(:session_after) do
        create(:session, :scheduled, user: patient,
               scheduled_at: effective_from + 7.days)
      end

      let!(:old_schedule) do
        create(:weekly_schedule, :wednesday, user: patient,
               time: "10:00", effective_from: 1.month.ago.to_date, effective_until: nil)
      end

      before do
        build_service(
          effective_from:  effective_from,
          schedule_params: { weekdays: ["friday"], sessions_per_week: 1, session_time: "14:00" }
        ).call
      end

      it "fecha o schedule antigo com effective_until = effective_from - 1 dia" do
        expect(old_schedule.reload.effective_until).to eq(effective_from - 1.day)
      end

      it "NÃO cancela sessões anteriores à data de vigência" do
        expect(session_before.reload.status).to eq("scheduled")
      end

      it "cancela sessões scheduled a partir da data de vigência" do
        expect(session_after.reload.status).to eq("cancelled")
      end

      it "cria novo schedule com o dia e vigência corretos" do
        new_schedule = patient.weekly_schedules.find_by(effective_from: effective_from)
        expect(new_schedule).to be_present
        expect(new_schedule.weekday).to eq("friday")
        expect(new_schedule.time).to eq("14:00")
      end

      it "preserva o schedule histórico (não destrói registros antigos)" do
        expect(patient.weekly_schedules.where(weekday: :wednesday)).to exist
      end
    end

    context "não cancela sessões com status diferente de scheduled" do
      let!(:completed_session) do
        create(:session, :completed, user: patient,
               scheduled_at: 2.weeks.from_now)
      end

      let!(:absent_session) do
        create(:session, :absent, user: patient,
               scheduled_at: 3.weeks.from_now)
      end

      it "não altera sessões completed" do
        build_service(effective_from: Date.current).call
        expect(completed_session.reload.status).to eq("completed")
      end

      it "não altera sessões absent" do
        build_service(effective_from: Date.current).call
        expect(absent_session.reload.status).to eq("absent")
      end
    end

    context "não cancela sessões do tipo extra" do
      let!(:extra_session) do
        create(:session, :scheduled, :extra, user: patient,
               scheduled_at: 2.weeks.from_now)
      end

      it "preserva sessões extra mesmo após a data de vigência" do
        build_service(effective_from: Date.current).call
        expect(extra_session.reload.status).to eq("scheduled")
      end
    end

    context "múltiplos dias da semana" do
      it "cria um weekly_schedule para cada dia informado" do
        build_service(
          schedule_params: {
            weekdays:          ["monday", "wednesday", "friday"],
            sessions_per_week: 3,
            session_time:      "09:00"
          }
        ).call

        expect(patient.weekly_schedules.where(effective_from: Date.current).count).to eq(3)
      end
    end

    context "idempotência do fechamento de schedules" do
      it "não fecha schedules que já estão fechados" do
        expired = create(:weekly_schedule, :expired, user: patient)

        build_service(
          schedule_params: { weekdays: ["monday"], sessions_per_week: 1, session_time: "09:00" }
        ).call

        # effective_until original (2020-12-31) deve permanecer intacto:
        # o schedule já está encerrado no passado, então não satisfaz
        # `effective_until >= effective_from` e não é tocado pelo update_all.
        expect(expired.reload.effective_until).to eq(Date.new(2020, 12, 31))
      end
    end
  end

  # VALIDAÇÕES DE PARÂMETROS
  describe "validações de parâmetros" do
    it "levanta Error se weekdays estiver vazio" do
      service = build_service(
        schedule_params: { weekdays: [], sessions_per_week: 1, session_time: "10:00" }
      )
      expect { service.call }.to raise_error(ScheduleChangeService::Error, /dia da semana/)
    end

    it "levanta Error se weekdays for nil" do
      service = build_service(
        schedule_params: { weekdays: nil, sessions_per_week: 1, session_time: "10:00" }
      )
      expect { service.call }.to raise_error(ScheduleChangeService::Error, /dia da semana/)
    end

    it "levanta Error se session_time estiver em branco" do
      service = build_service(
        schedule_params: { weekdays: ["monday"], sessions_per_week: 1, session_time: "" }
      )
      expect { service.call }.to raise_error(ScheduleChangeService::Error, /Horário/)
    end

    it "levanta Error se session_time for nil" do
      service = build_service(
        schedule_params: { weekdays: ["monday"], sessions_per_week: 1, session_time: nil }
      )
      expect { service.call }.to raise_error(ScheduleChangeService::Error, /Horário/)
    end

    it "levanta RecordInvalid se o weekday for inválido" do
      service = build_service(
        schedule_params: { weekdays: ["dia_invalido"], sessions_per_week: 1, session_time: "10:00" }
      )
      expect { service.call }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  # TRANSIÇÃO PARA EXTRA
  describe "#call (schedule_type: 'extra'" do
    let(:effective_from) { Date.current + 7.days }

    let!(:session_before) do
      create(:session, :scheduled, user: patient,
             scheduled_at: effective_from - 3.days)
    end

    let!(:session_after) do
      create(:session, :scheduled, user: patient,
             scheduled_at: effective_from + 7.days)
    end

    let!(:old_schedule) do
      create(:weekly_schedule, user: patient, effective_from: 1.month.ago.to_date)
    end

    # Definida antes do before para garantir existência antes da chamada ao service.
    # Usa horário distinto de session_after para evitar conflito de sobreposição (mínimo 1h).
    let!(:extra_session) do
      create(:session, :scheduled, :extra, user: patient,
             scheduled_at: effective_from + 14.days)
    end

    before do
      build_service(schedule_type: "extra", effective_from: effective_from).call
    end

    it "retorna o patient" do
      result = build_service(schedule_type: "extra", effective_from: effective_from).call
      expect(result).to eq(patient)
    end

    it "fecha o schedule regular ativo" do
      expect(old_schedule.reload.effective_until).to eq(effective_from - 1.day)
    end

    it "não cancela sessões antes da vigência" do
      expect(session_before.reload.status).to eq("scheduled")
    end

    it "cancela sessões regulares scheduled após a vigência" do
      expect(session_after.reload.status).to eq("cancelled")
    end

    it "preserva sessões do tipo extra mesmo após a vigência" do
      expect(extra_session.reload.status).to eq("scheduled")
    end

    it "preserva o registro histórico de weekly_schedules" do
      expect(patient.weekly_schedules.count).to eq(1)
      expect(patient.weekly_schedules.first.id).to eq(old_schedule.id)
    end

    it "não cria novos weekly_schedules" do
      expect(patient.weekly_schedules.where("effective_from >= ?", effective_from)).to be_empty
    end
  end
  
  # SCHEDULE TYPE DESCONHECIDO
  describe "#call (schedule_type desconhecido" do
    it "retorna o patient sem criar schedules nem cancelar sessões" do
      result = build_service(schedule_type: "vacation").call

      expect(result).to eq(patient)
      expect(patient.weekly_schedules.count).to eq(0)
      expect(patient.sessions.count).to eq(0)
    end
  end
end
