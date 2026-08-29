require "rails_helper"

RSpec.describe RecurringSchedule, type: :model do
  include_context "com fuso de São Paulo"

  subject(:schedule) { build(:recurring_schedule) }

  describe "validações" do
    context "com dados válidos" do
      it "é válido" do
        expect(schedule).to be_valid
      end
    end

    describe "presença de campos obrigatórios" do
      it "é inválido sem user" do
        schedule.user = nil
        expect(schedule).to be_invalid
        expect(schedule.errors[:user]).to be_present
      end

      it "é inválido sem weekday" do
        schedule.weekday = nil
        expect(schedule).to be_invalid
        expect(schedule.errors[:weekday]).to be_present
      end

      it "é inválido sem start_time" do
        schedule.start_time = nil
        expect(schedule).to be_invalid
        expect(schedule.errors[:start_time]).to be_present
      end

      it "é inválido sem duration_minutes" do
        schedule.duration_minutes = nil
        expect(schedule).to be_invalid
        expect(schedule.errors[:duration_minutes]).to be_present
      end
    end

    describe "inclusão de weekday" do
      it "é válido com weekday 0 (domingo)" do
        schedule.weekday = 0
        expect(schedule).to be_valid
      end

      it "é válido com weekday 6 (sábado)" do
        schedule.weekday = 6
        expect(schedule).to be_valid
      end

      it "é inválido com weekday negativo" do
        schedule.weekday = -1
        expect(schedule).to be_invalid
        expect(schedule.errors[:weekday]).to be_present
      end

      it "é inválido com weekday maior que 6" do
        schedule.weekday = 7
        expect(schedule).to be_invalid
        expect(schedule.errors[:weekday]).to be_present
      end
    end

    describe "numericidade de duration_minutes" do
      it "é inválido com duration_minutes igual a 0" do
        schedule.duration_minutes = 0
        expect(schedule).to be_invalid
        expect(schedule.errors[:duration_minutes]).to be_present
      end

      it "é inválido com duration_minutes negativo" do
        schedule.duration_minutes = -10
        expect(schedule).to be_invalid
        expect(schedule.errors[:duration_minutes]).to be_present
      end

      it "é válido com duration_minutes igual a 60" do
        schedule.duration_minutes = 60
        expect(schedule).to be_valid
      end

      it "é inválido com duration_minutes maior que 60" do
        schedule.duration_minutes = 61
        expect(schedule).to be_invalid
        expect(schedule.errors[:duration_minutes]).to be_present
      end
    end

    describe "formato de meet_link" do
      it "é válido sem meet_link" do
        schedule.meet_link = nil
        expect(schedule).to be_valid
      end

      it "é válido com URL https" do
        schedule.meet_link = "https://meet.google.com/abc-defg-hij"
        expect(schedule).to be_valid
      end

      it "é inválido com URL http (link de sessão clínica não trafega em claro)" do
        schedule.meet_link = "http://meet.google.com/abc-defg-hij"
        expect(schedule).to be_invalid
        expect(schedule.errors[:meet_link]).to be_present
      end

      it "é inválido com meet_link sem protocolo" do
        schedule.meet_link = "meet.google.com/abc-defg-hij"
        expect(schedule).to be_invalid
        expect(schedule.errors[:meet_link]).to be_present
      end

      it "é inválido com meet_link como texto aleatório" do
        schedule.meet_link = "link inválido"
        expect(schedule).to be_invalid
        expect(schedule.errors[:meet_link]).to be_present
      end
    end
  end

  describe "associações" do
    it { is_expected.to belong_to(:user) }
    it { is_expected.to have_many(:sessions) }
  end

  describe "escopos" do
    let!(:ativo)   { create(:recurring_schedule, active: true) }
    let!(:inativo) { create(:recurring_schedule, :inactive) }

    describe ".active" do
      it "retorna apenas agendas ativas" do
        expect(described_class.active).to include(ativo)
        expect(described_class.active).not_to include(inativo)
      end
    end
  end

  describe "#end_time" do
    let(:schedule) { build(:recurring_schedule, start_time: "14:00:00", duration_minutes: 50) }

    it "retorna start_time + duration_minutes" do
      expected = schedule.start_time + 50.minutes
      expect(schedule.end_time).to eq(expected)
    end

    it "retorna corretamente para 60 minutos" do
      schedule.duration_minutes = 60
      expected = schedule.start_time + 60.minutes
      expect(schedule.end_time).to eq(expected)
    end
  end

  describe "#weekday_name" do
    nomes = {
      0 => "domingo",
      1 => "segunda-feira",
      2 => "terça-feira",
      3 => "quarta-feira",
      4 => "quinta-feira",
      5 => "sexta-feira",
      6 => "sábado"
    }

    nomes.each do |dia, nome|
      context "quando weekday é #{dia}" do
        let(:schedule) { build(:recurring_schedule, weekday: dia) }

        it "retorna '#{nome}'" do
          expect(schedule.weekday_name).to eq(nome)
        end
      end
    end
  end

  describe "callbacks ao alterar agenda" do
    let(:cliente)  { create(:user, :client) }
    let(:schedule) { create(:recurring_schedule, user: cliente) }

    let!(:sessao_futura) do
      create(:session,
        recurring_schedule: schedule,
        user: cliente,
        start_time: 1.week.from_now.beginning_of_hour,
        end_time: 1.week.from_now.beginning_of_hour + 50.minutes,
        status: :scheduled)
    end

    let!(:sessao_passada) do
      create(:session,
        recurring_schedule: schedule,
        user: cliente,
        start_time: 1.week.ago.beginning_of_hour,
        end_time: 1.week.ago.beginning_of_hour + 50.minutes,
        status: :completed)
    end

    context "quando weekday é alterado" do
      let(:novo_dia) { (schedule.weekday + 1) % 7 }

      before { schedule.update!(weekday: novo_dia) }

      it "remove sessões futuras vinculadas" do
        expect(Session.exists?(sessao_futura.id)).to be false
      end

      it "preserva sessões passadas" do
        expect(Session.exists?(sessao_passada.id)).to be true
      end
    end

    context "quando start_time é alterado" do
      before { schedule.update!(start_time: "10:00:00") }

      it "remove sessões futuras vinculadas" do
        expect(Session.exists?(sessao_futura.id)).to be false
      end

      it "preserva sessões passadas" do
        expect(Session.exists?(sessao_passada.id)).to be true
      end
    end

    context "quando apenas meet_link é alterado" do
      before { schedule.update!(meet_link: "https://meet.google.com/novo-link-xyz") }

      it "não remove sessões futuras" do
        expect(Session.exists?(sessao_futura.id)).to be true
      end

      it "não remove sessões passadas" do
        expect(Session.exists?(sessao_passada.id)).to be true
      end
    end

    context "quando active é alterado para false" do
      before { schedule.update!(active: false) }

      it "remove sessões futuras vinculadas" do
        expect(Session.exists?(sessao_futura.id)).to be false
      end

      it "preserva sessões passadas" do
        expect(Session.exists?(sessao_passada.id)).to be true
      end
    end
  end

  describe "audit trail" do
    let(:performing_user) { create(:user, :therapist) }

    before { Current.user = performing_user }
    after  { Current.user = nil }

    context "quando RecurringSchedule é alterada" do
      let(:schedule) { create(:recurring_schedule) }

      it "registra um AuditLog" do
        expect { schedule.update!(weekday: (schedule.weekday + 1) % 7) }
          .to change(AuditLog, :count).by(1)
      end

      it "registra action 'update' e entity correto" do
        schedule.update!(weekday: (schedule.weekday + 1) % 7)
        log = AuditLog.last
        expect(log.action).to eq("update")
        expect(log.entity_type).to eq("RecurringSchedule")
        expect(log.entity_id).to eq(schedule.id)
      end
    end
  end
end
