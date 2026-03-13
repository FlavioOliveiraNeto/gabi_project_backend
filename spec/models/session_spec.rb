# frozen_string_literal: true

require "rails_helper"

RSpec.describe Session, type: :model do
  include_context "with São Paulo timezone"

  subject(:session) { build(:session) }

  # ---------------------------------------------------------------------------
  # Validações — campos obrigatórios e lógica temporal
  # ---------------------------------------------------------------------------
  describe "validações" do
    context "com dados válidos" do
      it "é válida" do
        expect(session).to be_valid
      end
    end

    describe "presença de campos obrigatórios" do
      it "é inválida sem user" do
        session.user = nil
        expect(session).to be_invalid
        expect(session.errors[:user]).to be_present
      end

      it "é inválida sem start_time" do
        session.start_time = nil
        expect(session).to be_invalid
        expect(session.errors[:start_time]).to be_present
      end

      it "é inválida sem end_time" do
        session.end_time = nil
        expect(session).to be_invalid
        expect(session.errors[:end_time]).to be_present
      end

      it "é inválida sem status" do
        session.status = nil
        expect(session).to be_invalid
        expect(session.errors[:status]).to be_present
      end

      it "é inválida sem session_type" do
        session.session_type = nil
        expect(session).to be_invalid
        expect(session.errors[:session_type]).to be_present
      end
    end

    describe "lógica temporal" do
      it "é inválida quando end_time é anterior a start_time" do
        session.end_time = session.start_time - 30.minutes
        expect(session).to be_invalid
        expect(session.errors[:end_time]).to be_present
      end

      it "é inválida quando end_time é igual a start_time" do
        session.end_time = session.start_time
        expect(session).to be_invalid
        expect(session.errors[:end_time]).to be_present
      end

      it "é válida quando end_time é posterior a start_time" do
        session.end_time = session.start_time + 50.minutes
        expect(session).to be_valid
      end
    end

    describe "duração máxima de 60 minutos" do
      it "é inválida quando duração excede 60 minutos" do
        session.end_time = session.start_time + 61.minutes
        expect(session).to be_invalid
        expect(session.errors[:end_time]).to be_present
      end

      it "é válida com duração de exatamente 60 minutos" do
        session.end_time = session.start_time + 60.minutes
        expect(session).to be_valid
      end

      it "é válida com duração de 30 minutos" do
        session.end_time = session.start_time + 30.minutes
        expect(session).to be_valid
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Conflito de agenda com outras sessões
  # ---------------------------------------------------------------------------
  describe "conflito de agenda" do
    let(:base)        { 2.weeks.from_now.beginning_of_hour }
    let!(:existente) do
      create(:session,
        start_time: base,
        end_time: base + 50.minutes,
        status: :scheduled)
    end

    context "when nova sessão está exatamente no mesmo horário" do
      let(:nova) { build(:session, start_time: base, end_time: base + 50.minutes) }

      it "é inválida" do
        expect(nova).to be_invalid
        expect(nova.errors[:start_time]).to be_present
      end
    end

    context "when nova sessão começa durante outra" do
      let(:nova) do
        build(:session,
          start_time: base + 20.minutes,
          end_time: base + 70.minutes)
      end

      it "é inválida" do
        expect(nova).to be_invalid
        expect(nova.errors[:start_time]).to be_present
      end
    end

    context "when nova sessão termina durante outra" do
      let(:nova) do
        build(:session,
          start_time: base - 20.minutes,
          end_time: base + 20.minutes)
      end

      it "é inválida" do
        expect(nova).to be_invalid
        expect(nova.errors[:start_time]).to be_present
      end
    end

    context "when nova sessão engloba outra completamente" do
      let(:nova) do
        build(:session,
          start_time: base - 10.minutes,
          end_time: base + 60.minutes)
      end

      it "é inválida" do
        expect(nova).to be_invalid
        expect(nova.errors[:start_time]).to be_present
      end
    end

    context "when nova sessão começa exatamente quando outra termina" do
      it "é válida (sem sobreposição)" do
        nova = build(:session,
          start_time: base + 50.minutes,
          end_time: base + 50.minutes + 50.minutes)
        nova.validate
        expect(nova.errors[:start_time]).not_to include(a_string_matching(/conflito/i))
      end
    end

    context "when nova sessão termina exatamente quando outra começa" do
      let(:nova) do
        build(:session,
          start_time: base - 50.minutes,
          end_time: base)
      end

      it "é válida (sem sobreposição)" do
        nova.validate
        expect(nova.errors[:start_time]).not_to include(a_string_matching(/conflito/i))
      end
    end

    context "when sessões são em dias diferentes" do
      let(:nova) do
        build(:session,
          start_time: base + 1.day,
          end_time: base + 1.day + 50.minutes)
      end

      it "é válida" do
        expect(nova).to be_valid
      end
    end

    context "when sessão existente está cancelada" do
      let!(:cancelada) do
        create(:session,
          start_time: base + 2.hours,
          end_time: base + 2.hours + 50.minutes,
          status: :cancelled)
      end

      let(:nova) do
        build(:session,
          start_time: base + 2.hours,
          end_time: base + 2.hours + 50.minutes)
      end

      it "é válida (sessões canceladas não geram conflito)" do
        expect(nova).to be_valid
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Conflito com CalendarBlock
  # ---------------------------------------------------------------------------
  describe "conflito com CalendarBlock" do
    let(:base) { 3.weeks.from_now.beginning_of_hour }

    let!(:bloco) do
      create(:calendar_block,
        start_time: base,
        end_time: base + 4.hours,
        reason: "Consulta médica")
    end

    context "when sessão está completamente dentro do bloqueio" do
      let(:sessao) do
        build(:session,
          start_time: base + 30.minutes,
          end_time: base + 80.minutes)
      end

      it "é inválida" do
        expect(sessao).to be_invalid
        expect(sessao.errors[:start_time]).to be_present
      end
    end

    context "when sessão sobrepõe parcialmente o início do bloqueio" do
      let(:sessao) do
        build(:session,
          start_time: base - 30.minutes,
          end_time: base + 30.minutes)
      end

      it "é inválida" do
        expect(sessao).to be_invalid
        expect(sessao.errors[:start_time]).to be_present
      end
    end

    context "when sessão sobrepõe parcialmente o fim do bloqueio" do
      let(:sessao) do
        build(:session,
          start_time: base + 3.hours + 30.minutes,
          end_time: base + 3.hours + 30.minutes + 50.minutes)
      end

      it "é inválida" do
        expect(sessao).to be_invalid
        expect(sessao.errors[:start_time]).to be_present
      end
    end

    context "when sessão está fora do bloqueio" do
      let(:sessao) do
        build(:session,
          start_time: base + 5.hours,
          end_time: base + 5.hours + 50.minutes)
      end

      it "é válida" do
        expect(sessao).to be_valid
      end
    end

    context "when sessão começa exatamente quando o bloqueio termina" do
      let(:sessao) do
        build(:session,
          start_time: base + 4.hours,
          end_time: base + 4.hours + 50.minutes)
      end

      it "é válida" do
        expect(sessao).to be_valid
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Associações
  # ---------------------------------------------------------------------------
  describe "associações" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to belong_to(:recurring_schedule).optional }
    it { is_expected.to have_one(:clinical_note) }
  end

  # ---------------------------------------------------------------------------
  # Transições de status
  # ---------------------------------------------------------------------------
  describe "transições de status" do
    describe "scheduled → cancelled (permitida)" do
      let(:sessao) { create(:session, status: :scheduled) }

      it "é permitida via cancel!" do
        expect { sessao.cancel! }
          .to change { sessao.reload.status }
          .from("scheduled").to("cancelled")
      end
    end

    describe "completed → missed (permitida)" do
      let(:sessao) { create(:session, :past, status: :completed) }

      it "é permitida via mark_as_missed!" do
        expect { sessao.mark_as_missed! }
          .to change { sessao.reload.status }
          .from("completed").to("missed")
      end
    end

    describe "scheduled → completed (apenas via job)" do
      let(:sessao) { create(:session, status: :scheduled) }

      it "é inválida quando atribuída diretamente" do
        sessao.status = :completed
        expect(sessao).to be_invalid
        expect(sessao.errors[:status]).to be_present
      end

      it "é permitida via auto_complete! (método do job)" do
        expect { sessao.auto_complete! }
          .to change { sessao.reload.status }
          .from("scheduled").to("completed")
      end
    end

    describe "scheduled → missed (proibida diretamente)" do
      let(:sessao) { create(:session, status: :scheduled) }

      it "levanta erro ao tentar mark_as_missed! em sessão agendada" do
        expect { sessao.mark_as_missed! }.to raise_error(described_class::InvalidTransition)
      end
    end

    describe "completed → scheduled (proibida)" do
      let(:sessao) { create(:session, :past, status: :completed) }

      it "é inválida" do
        sessao.status = :scheduled
        expect(sessao).to be_invalid
        expect(sessao.errors[:status]).to be_present
      end
    end

    describe "completed → cancelled (proibida)" do
      let(:sessao) { create(:session, :past, status: :completed) }

      it "levanta erro ao tentar cancel!" do
        expect { sessao.cancel! }.to raise_error(described_class::InvalidTransition)
      end
    end

    describe "cancelled → qualquer estado (proibida)" do
      let(:sessao) { create(:session, :cancelled) }

      it "levanta erro ao tentar cancel! novamente" do
        expect { sessao.cancel! }.to raise_error(described_class::InvalidTransition)
      end

      it "levanta erro ao tentar auto_complete!" do
        expect { sessao.auto_complete! }.to raise_error(described_class::InvalidTransition)
      end

      it "é inválida ao tentar voltar para scheduled" do
        sessao.status = :scheduled
        expect(sessao).to be_invalid
      end
    end

    describe "missed → qualquer estado (proibida)" do
      let(:sessao) { create(:session, :missed) }

      it "levanta erro ao tentar mark_as_missed! novamente" do
        expect { sessao.mark_as_missed! }.to raise_error(described_class::InvalidTransition)
      end

      it "levanta erro ao tentar cancel!" do
        expect { sessao.cancel! }.to raise_error(described_class::InvalidTransition)
      end

      it "é inválida ao tentar voltar para scheduled" do
        sessao.status = :scheduled
        expect(sessao).to be_invalid
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Escopos
  # ---------------------------------------------------------------------------
  describe "escopos" do
    let(:cliente) { create(:user, :client) }

    let!(:sessao_agendada)   { create(:session, user: cliente, status: :scheduled) }
    let!(:sessao_completada) { create(:session, :past, user: cliente, status: :completed) }
    let!(:sessao_falta)      { create(:session, :missed, user: cliente) }
    let!(:sessao_cancelada)  { create(:session, :cancelled, user: cliente) }

    describe ".scheduled" do
      it "retorna apenas sessões com status scheduled" do
        expect(described_class.scheduled).to include(sessao_agendada)
        expect(described_class.scheduled).not_to include(sessao_completada, sessao_falta, sessao_cancelada)
      end
    end

    describe ".completed" do
      it "retorna apenas sessões com status completed" do
        expect(described_class.completed).to include(sessao_completada)
        expect(described_class.completed).not_to include(sessao_agendada, sessao_falta, sessao_cancelada)
      end
    end

    describe ".missed" do
      it "retorna apenas sessões com status missed" do
        expect(described_class.missed).to include(sessao_falta)
        expect(described_class.missed).not_to include(sessao_agendada, sessao_completada, sessao_cancelada)
      end
    end

    describe ".cancelled" do
      it "retorna apenas sessões com status cancelled" do
        expect(described_class.cancelled).to include(sessao_cancelada)
        expect(described_class.cancelled).not_to include(sessao_agendada, sessao_completada, sessao_falta)
      end
    end

    describe ".upcoming" do
      let!(:futura)  { create(:session, :future, user: cliente, status: :scheduled) }
      let!(:passada) { create(:session, :past, user: cliente, status: :scheduled) }

      it "retorna sessões scheduled com start_time no futuro" do
        expect(described_class.upcoming).to include(futura)
        expect(described_class.upcoming).not_to include(passada)
      end

      it "não retorna sessões não-scheduled mesmo que futuras" do
        cancelada_futura = create(:session, :future, :cancelled, user: cliente)
        expect(described_class.upcoming).not_to include(cancelada_futura)
      end
    end

    describe ".past" do
      let!(:futura)  { create(:session, :future, user: cliente) }
      let!(:passada) { create(:session, :past, user: cliente) }

      it "retorna sessões com start_time no passado" do
        expect(described_class.past).to include(passada)
        expect(described_class.past).not_to include(futura)
      end
    end

    describe ".for_user(user)" do
      let(:outro_cliente) { create(:user, :client) }
      let!(:sessao_outro) { create(:session, user: outro_cliente, status: :scheduled) }

      it "filtra sessões do usuário especificado" do
        resultado = described_class.for_user(cliente)
        expect(resultado).to include(sessao_agendada)
        expect(resultado).not_to include(sessao_outro)
      end
    end

    describe ".in_range(start_date, end_date)" do
      let(:inicio) { 3.weeks.from_now }
      let(:fim)    { 5.weeks.from_now }

      let!(:dentro_do_intervalo) do
        create(:session,
          user: cliente,
          start_time: 4.weeks.from_now.beginning_of_hour,
          end_time: 4.weeks.from_now.beginning_of_hour + 50.minutes)
      end

      let!(:fora_do_intervalo) do
        create(:session,
          user: cliente,
          start_time: 7.weeks.from_now.beginning_of_hour,
          end_time: 7.weeks.from_now.beginning_of_hour + 50.minutes)
      end

      it "retorna sessões cujo start_time está dentro do intervalo" do
        resultado = described_class.in_range(inicio, fim)
        expect(resultado).to include(dentro_do_intervalo)
        expect(resultado).not_to include(fora_do_intervalo)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Métodos de instância
  # ---------------------------------------------------------------------------
  describe "#duration_in_minutes" do
    let(:sessao) do
      build(:session,
        start_time: Time.current.beginning_of_hour,
        end_time: Time.current.beginning_of_hour + 50.minutes)
    end

    it "retorna 50 para sessão de 50 minutos" do
      expect(sessao.duration_in_minutes).to eq(50)
    end

    it "retorna 30 para sessão de 30 minutos" do
      sessao.end_time = sessao.start_time + 30.minutes
      expect(sessao.duration_in_minutes).to eq(30)
    end
  end

  describe "#recurring?" do
    it "retorna true quando session_type é recurring" do
      session.session_type = :recurring
      expect(session.recurring?).to be true
    end

    it "retorna false quando session_type é extra" do
      session.session_type = :extra
      expect(session.recurring?).to be false
    end
  end

  describe "#extra?" do
    it "retorna true quando session_type é extra" do
      session.session_type = :extra
      expect(session.extra?).to be true
    end

    it "retorna false quando session_type é recurring" do
      session.session_type = :recurring
      expect(session.extra?).to be false
    end
  end

  describe "#cancellable?" do
    it "retorna true apenas quando status é scheduled" do
      session.status = :scheduled
      expect(session.cancellable?).to be true
    end

    it "retorna false quando status é completed" do
      session.status = :completed
      expect(session.cancellable?).to be false
    end

    it "retorna false quando status é cancelled" do
      session.status = :cancelled
      expect(session.cancellable?).to be false
    end

    it "retorna false quando status é missed" do
      session.status = :missed
      expect(session.cancellable?).to be false
    end
  end

  describe "#can_mark_as_missed?" do
    it "retorna true apenas quando status é completed" do
      session.status = :completed
      expect(session.can_mark_as_missed?).to be true
    end

    it "retorna false quando status é scheduled" do
      session.status = :scheduled
      expect(session.can_mark_as_missed?).to be false
    end

    it "retorna false quando status é missed" do
      session.status = :missed
      expect(session.can_mark_as_missed?).to be false
    end

    it "retorna false quando status é cancelled" do
      session.status = :cancelled
      expect(session.can_mark_as_missed?).to be false
    end
  end

  # ---------------------------------------------------------------------------
  # Audit trail
  # ---------------------------------------------------------------------------
  describe "audit trail" do
    let(:performing_user) { create(:user, :therapist) }

    before { Current.user = performing_user }
    after  { Current.user = nil }

    context "when sessão é criada" do
      it "registra um AuditLog" do
        expect { create(:session) }.to change(AuditLog, :count).by(1)
      end

      it "registra action 'create' com entity correto" do
        sessao = create(:session)
        log = AuditLog.last
        expect(log.action).to eq("create")
        expect(log.entity_type).to eq("Session")
        expect(log.entity_id).to eq(sessao.id)
      end
    end

    context "when sessão é cancelada" do
      let(:sessao) { create(:session, status: :scheduled) }

      it "registra um AuditLog" do
        expect { sessao.cancel! }.to change(AuditLog, :count).by(1)
      end

      it "registra action 'cancel'" do
        sessao.cancel!
        log = AuditLog.last
        expect(log.action).to eq("cancel")
        expect(log.entity_type).to eq("Session")
        expect(log.entity_id).to eq(sessao.id)
      end
    end

    context "when sessão é marcada como falta" do
      let(:sessao) { create(:session, :past, status: :completed) }

      it "registra um AuditLog" do
        expect { sessao.mark_as_missed! }.to change(AuditLog, :count).by(1)
      end

      it "registra action 'mark_as_missed'" do
        sessao.mark_as_missed!
        log = AuditLog.last
        expect(log.action).to eq("mark_as_missed")
        expect(log.entity_type).to eq("Session")
        expect(log.entity_id).to eq(sessao.id)
      end
    end
  end
end
