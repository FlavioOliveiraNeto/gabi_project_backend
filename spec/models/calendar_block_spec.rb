# frozen_string_literal: true

require "rails_helper"

RSpec.describe CalendarBlock, type: :model do
  include_context "with São Paulo timezone"

  subject(:block) { build(:calendar_block) }

  # ---------------------------------------------------------------------------
  # Validações
  # ---------------------------------------------------------------------------
  describe "validações" do
    context "com dados válidos" do
      it "é válido" do
        expect(block).to be_valid
      end
    end

    describe "presença de campos obrigatórios" do
      it "é inválido sem start_time" do
        block.start_time = nil
        expect(block).to be_invalid
        expect(block.errors[:start_time]).to be_present
      end

      it "é inválido sem end_time" do
        block.end_time = nil
        expect(block).to be_invalid
        expect(block.errors[:end_time]).to be_present
      end

      it "é inválido sem reason" do
        block.reason = nil
        expect(block).to be_invalid
        expect(block.errors[:reason]).to be_present
      end

      it "é inválido com reason em branco" do
        block.reason = "  "
        expect(block).to be_invalid
        expect(block.errors[:reason]).to be_present
      end
    end

    describe "lógica temporal" do
      it "é inválido quando end_time é anterior a start_time" do
        block.end_time = block.start_time - 1.hour
        expect(block).to be_invalid
        expect(block.errors[:end_time]).to be_present
      end

      it "é inválido quando end_time é igual a start_time" do
        block.end_time = block.start_time
        expect(block).to be_invalid
        expect(block.errors[:end_time]).to be_present
      end

      it "é válido quando end_time é posterior a start_time" do
        block.end_time = block.start_time + 1.hour
        expect(block).to be_valid
      end
    end

    describe "sobreposição de bloqueios" do
      let(:base)        { 2.days.from_now.beginning_of_hour }
      let!(:existente) do
        create(:calendar_block,
          start_time: base,
          end_time: base + 3.hours,
          reason: "Bloco existente")
      end

      context "when novo bloco sobrepõe exatamente o existente" do
        let(:novo) { build(:calendar_block, start_time: base, end_time: base + 3.hours) }

        it "é inválido" do
          expect(novo).to be_invalid
          expect(novo.errors[:start_time]).to be_present
        end
      end

      context "when novo bloco começa durante o existente" do
        let(:novo) do
          build(:calendar_block,
            start_time: base + 1.hour,
            end_time: base + 4.hours)
        end

        it "é inválido" do
          expect(novo).to be_invalid
          expect(novo.errors[:start_time]).to be_present
        end
      end

      context "when novo bloco termina durante o existente" do
        let(:novo) do
          build(:calendar_block,
            start_time: base - 1.hour,
            end_time: base + 1.hour)
        end

        it "é inválido" do
          expect(novo).to be_invalid
          expect(novo.errors[:start_time]).to be_present
        end
      end

      context "when novo bloco engloba completamente o existente" do
        let(:novo) do
          build(:calendar_block,
            start_time: base - 1.hour,
            end_time: base + 4.hours)
        end

        it "é inválido" do
          expect(novo).to be_invalid
          expect(novo.errors[:start_time]).to be_present
        end
      end

      context "when novo bloco começa exatamente quando o existente termina" do
        let(:novo) do
          build(:calendar_block,
            start_time: base + 3.hours,
            end_time: base + 5.hours)
        end

        it "é válido (não há sobreposição)" do
          expect(novo).to be_valid
        end
      end

      context "when novo bloco termina exatamente quando o existente começa" do
        let(:novo) do
          build(:calendar_block,
            start_time: base - 2.hours,
            end_time: base)
        end

        it "é válido (não há sobreposição)" do
          expect(novo).to be_valid
        end
      end

      context "when novo bloco está em período sem sobreposição" do
        let(:novo) do
          build(:calendar_block,
            start_time: base + 5.hours,
            end_time: base + 7.hours)
        end

        it "é válido" do
          expect(novo).to be_valid
        end
      end

      context "when atualizando o próprio bloco (sem conflito consigo mesmo)" do
        it "é válido ao atualizar reason mantendo horário" do
          existente.reason = "Férias atualizadas"
          expect(existente).to be_valid
        end
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Métodos de instância
  # ---------------------------------------------------------------------------
  describe "#duration_in_hours" do
    it "retorna a duração correta em horas inteiras" do
      base = 3.days.from_now.beginning_of_hour
      bloco = build(:calendar_block, start_time: base, end_time: base + 4.hours)
      expect(bloco.duration_in_hours).to eq(4.0)
    end

    it "retorna fração quando a duração não é inteira" do
      base = 3.days.from_now.beginning_of_hour
      bloco = build(:calendar_block, start_time: base, end_time: base + 90.minutes)
      expect(bloco.duration_in_hours).to eq(1.5)
    end

    it "retorna a duração para blocos longos" do
      base = 5.days.from_now.beginning_of_hour
      bloco = build(:calendar_block, start_time: base, end_time: base + 8.hours)
      expect(bloco.duration_in_hours).to eq(8.0)
    end
  end

  # ---------------------------------------------------------------------------
  # Escopos
  # ---------------------------------------------------------------------------
  describe "escopos" do
    let!(:futuro)   { create(:calendar_block, :upcoming) }
    let!(:passado)  { create(:calendar_block, :past) }

    describe ".upcoming" do
      it "retorna bloqueios com start_time no futuro" do
        expect(described_class.upcoming).to include(futuro)
        expect(described_class.upcoming).not_to include(passado)
      end
    end

    describe ".covering(time)" do
      let(:base) { 3.days.from_now.beginning_of_hour }
      let!(:bloco_cobrindo) do
        create(:calendar_block,
          start_time: base,
          end_time: base + 4.hours,
          reason: "Bloco cobrindo")
      end

      it "retorna bloqueios que cobrem um momento dentro do intervalo" do
        momento = base + 2.hours
        expect(described_class.covering(momento)).to include(bloco_cobrindo)
      end

      it "não retorna bloqueios que não cobrem o momento" do
        momento = base + 6.hours
        expect(described_class.covering(momento)).not_to include(bloco_cobrindo)
      end

      it "retorna bloqueio quando momento é exatamente o start_time" do
        expect(described_class.covering(base)).to include(bloco_cobrindo)
      end

      it "não retorna bloqueio quando momento é exatamente o end_time" do
        expect(described_class.covering(base + 4.hours)).not_to include(bloco_cobrindo)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Audit trail
  # ---------------------------------------------------------------------------
  describe "audit trail" do
    let(:performing_user) { create(:user, :therapist) }

    before { Current.user = performing_user }
    after  { Current.user = nil }

    context "when CalendarBlock é criado" do
      it "registra um AuditLog" do
        expect { create(:calendar_block) }.to change(AuditLog, :count).by(1)
      end

      it "registra a action como 'create' e entity correto" do
        bloco = create(:calendar_block)
        log = AuditLog.last
        expect(log.action).to eq("create")
        expect(log.entity_type).to eq("CalendarBlock")
        expect(log.entity_id).to eq(bloco.id)
      end
    end
  end
end
