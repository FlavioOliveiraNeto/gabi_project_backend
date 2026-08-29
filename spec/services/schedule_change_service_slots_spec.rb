require 'rails_helper'

RSpec.describe ScheduleChangeService, "agenda com horários por dia" do
  let(:therapist) { create(:user, :therapist) }
  let(:patient)   { create(:user, :client, therapist: therapist) }
  let(:other)     { create(:user, :client, therapist: therapist) }

  def build_service(slots, overrides = {})
    described_class.new(**{
      patient:         patient,
      therapist:       therapist,
      effective_from:  Date.current,
      schedule_type:   "regular",
      schedule_params: { schedule_slots: slots }
    }.merge(overrides))
  end

  # 2026-03-02 é uma segunda-feira.
  def next_weekday(name, from: Date.current)
    wday = WeeklySchedule.weekdays[name.to_s]
    (from..(from + 7)).find { |d| d.wday == wday }
  end

  describe "horários distintos por dia" do
    it "cria um weekly_schedule por slot, cada um com seu próprio horário" do
      build_service([
        { weekday: "saturday",  time: "08:00" },
        { weekday: "wednesday", time: "19:00" }
      ]).call

      times = patient.weekly_schedules.pluck(:weekday, :time).to_h
      expect(times).to eq("saturday" => "08:00", "wednesday" => "19:00")
    end

    it "gera as sessões no horário correspondente a cada dia" do
      travel_to Time.zone.local(2026, 3, 2, 9, 0) do
        build_service([
          { weekday: "saturday",  time: "08:00" },
          { weekday: "wednesday", time: "19:00" }
        ]).call

        by_wday = patient.sessions.recurring.map { |s| [ s.start_time.wday, s.start_time.strftime("%H:%M") ] }.uniq
        expect(by_wday).to match_array([ [ 6, "08:00" ], [ 3, "19:00" ] ])
      end
    end

    it "aceita o payload legado (weekdays + session_time) aplicando o mesmo horário" do
      build_service(nil, schedule_params: {
        weekdays: [ "saturday", "wednesday" ], sessions_per_week: 2, session_time: "14:30"
      }).call

      expect(patient.weekly_schedules.pluck(:time).uniq).to eq([ "14:30" ])
      expect(patient.weekly_schedules.pluck(:weekday)).to match_array(%w[saturday wednesday])
    end
  end

  describe "validação de slots" do
    it "rejeita lista vazia" do
      expect { build_service([]).call }
        .to raise_error(described_class::Error, /ao menos um dia/i)
    end

    it "rejeita slot sem horário" do
      expect { build_service([ { weekday: "monday", time: "" } ]).call }
        .to raise_error(described_class::Error, /[Hh]orário/)
    end

    it "rejeita horário fora do formato HH:MM" do
      expect { build_service([ { weekday: "monday", time: "25:99" } ]).call }
        .to raise_error(described_class::Error, /[Hh]orário/)
    end

    it "rejeita dia da semana inválido" do
      expect { build_service([ { weekday: "sextou", time: "10:00" } ]).call }
        .to raise_error(described_class::Error, /dia da semana/i)
    end

    it "rejeita o mesmo dia da semana repetido" do
      expect {
        build_service([
          { weekday: "monday", time: "10:00" },
          { weekday: "monday", time: "11:00" }
        ]).call
      }.to raise_error(described_class::Error, /repetid|duplicad/i)
    end

    it "rejeita dois slots do próprio paciente que se sobrepõem entre si" do
      expect {
        build_service([
          { weekday: "monday",   time: "10:00" },
          { weekday: "thursday", time: "10:00" }
        ]).call
      }.not_to raise_error
    end
  end

  describe "conflito com sessão de outro paciente" do
    let!(:occupied) do
      create(:session, :scheduled, user: other,
             scheduled_at: Time.zone.local(2026, 3, 7, 14, 0),
             start_time:   Time.zone.local(2026, 3, 7, 14, 0),
             end_time:     Time.zone.local(2026, 3, 7, 14, 50))
    end

    let(:slots) do
      [ { weekday: "saturday", time: "14:30" }, { weekday: "wednesday", time: "14:30" } ]
    end

    around { |ex| travel_to(Time.zone.local(2026, 3, 2, 9, 0)) { ex.run } }

    it "levanta ConflictError em vez de agendar parcialmente" do
      expect { build_service(slots).call }.to raise_error(described_class::ConflictError)
    end

    it "não persiste nenhum weekly_schedule" do
      expect { build_service(slots).call rescue nil }
        .not_to change { patient.weekly_schedules.count }
    end

    it "não persiste NENHUMA sessão — nem a de quarta, que não conflita" do
      expect { build_service(slots).call rescue nil }
        .not_to change { patient.sessions.count }
    end

    it "expõe o slot conflitante com dia, horário e data" do
      error = build_service(slots).call rescue $!

      conflict = error.conflicts.first
      expect(error.conflicts.size).to eq(1)
      expect(conflict[:weekday]).to eq("saturday")
      expect(conflict[:time]).to eq("14:30")
      expect(conflict[:scheduled_at].to_date).to eq(Date.new(2026, 3, 7))
    end

    it "usa mensagem em pt-BR pedindo a troca de horário" do
      error = build_service(slots).call rescue $!
      expect(error.message).to match(/sábado/i).and match(/14:30/)
      expect(error.message).to match(/outro horário/i)
    end

    it "detecta sobreposição parcial dentro dos 50 minutos (14:00 vs 14:30)" do
      error = build_service([ { weekday: "saturday", time: "14:30" } ]).call rescue $!
      expect(error).to be_a(described_class::ConflictError)
    end

    it "rejeita horário encostado no fim da anterior (14:50) — falta o intervalo" do
      error = build_service([ { weekday: "saturday", time: "14:50" } ]).call rescue $!
      expect(error).to be_a(described_class::ConflictError)
    end

    it "rejeita horário dentro do intervalo de 10 minutos (14:55)" do
      error = build_service([ { weekday: "saturday", time: "14:55" } ]).call rescue $!
      expect(error).to be_a(described_class::ConflictError)
    end

    it "aceita 15:00 — 50 min de sessão + 10 min de intervalo" do
      expect { build_service([ { weekday: "saturday", time: "15:00" } ]).call }
        .not_to raise_error
    end

    it "aceita 13:00 — termina 13:50, 10 min antes da sessão das 14:00" do
      expect { build_service([ { weekday: "saturday", time: "13:00" } ]).call }
        .not_to raise_error
    end

    it "não conflita com sessão cancelada no mesmo horário" do
      occupied.update_column(:status, Session.statuses[:cancelled])
      expect { build_service([ { weekday: "saturday", time: "14:00" } ]).call }
        .not_to raise_error
    end

    it "não conflita com sessão de paciente de outra terapeuta" do
      occupied.update!(user: create(:user, :client, therapist: create(:user, :therapist)))
      expect { build_service([ { weekday: "saturday", time: "14:00" } ]).call }
        .not_to raise_error
    end
  end

  describe "conflito com bloqueio de agenda" do
    around { |ex| travel_to(Time.zone.local(2026, 3, 2, 9, 0)) { ex.run } }

    let!(:block) do
      create(:calendar_block, therapist: therapist,
             start_time: Time.zone.local(2026, 3, 7, 8, 0),
             end_time:   Time.zone.local(2026, 3, 7, 12, 0))
    end

    it "levanta ConflictError e não agenda nada" do
      expect {
        expect { build_service([ { weekday: "saturday", time: "08:00" } ]).call }
          .to raise_error(described_class::ConflictError)
      }.not_to change { patient.sessions.count }
    end
  end

  describe "rollback preserva a agenda anterior" do
    around { |ex| travel_to(Time.zone.local(2026, 3, 2, 9, 0)) { ex.run } }

    let!(:existing_schedule) do
      create(:weekly_schedule, user: patient, weekday: :monday, time: "09:00")
    end

    let!(:occupied) do
      create(:session, :scheduled, user: other,
             scheduled_at: Time.zone.local(2026, 3, 7, 14, 0),
             start_time:   Time.zone.local(2026, 3, 7, 14, 0),
             end_time:     Time.zone.local(2026, 3, 7, 14, 50))
    end

    it "mantém o weekly_schedule antigo aberto quando a troca falha" do
      build_service([ { weekday: "saturday", time: "14:00" } ]).call rescue nil

      expect(existing_schedule.reload.effective_until).to be_nil
    end

    it "não cancela as sessões futuras existentes quando a troca falha" do
      session = create(:session, :scheduled, user: patient,
                       scheduled_at: Time.zone.local(2026, 3, 9, 9, 0),
                       start_time:   Time.zone.local(2026, 3, 9, 9, 0),
                       end_time:     Time.zone.local(2026, 3, 9, 9, 50))

      build_service([ { weekday: "saturday", time: "14:00" } ]).call rescue nil

      expect(session.reload.status).to eq("scheduled")
    end
  end
end
