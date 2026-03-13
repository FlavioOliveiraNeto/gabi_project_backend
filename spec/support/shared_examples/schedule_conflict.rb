# Shared examples para validação de conflito de agenda.
#
# Regras de negócio cobertas:
#   1. Nenhuma sessão pode sobrepor outra sessão (start_time/end_time)
#   2. Nenhuma sessão pode sobrepor um CalendarBlock
#
# Tipos de sobreposição temporal validados:
#   - Início dentro de intervalo existente
#   - Fim dentro de intervalo existente
#   - Engloba intervalo existente (começa antes e termina depois)
#   - Idêntico ao intervalo existente
#
# ---------------------------------------------------------------------------
# CONTRATO — o spec pai deve definir via let:
#
#   subject { build(:session, start_time: ..., end_time: ...) }
#
# O registro conflitante deve existir no banco ANTES do subject ser validado
# (crie com create, não build).
# ---------------------------------------------------------------------------
#
# Exemplo de uso — conflito com outra Session:
#
#   describe "overlap validation" do
#     let!(:existing_session) do
#       create(:session,
#              start_time: Time.current.beginning_of_hour + 10.hours,
#              end_time:   Time.current.beginning_of_hour + 11.hours)
#     end
#
#     context "quando inicia durante sessão existente" do
#       subject do
#         build(:session,
#               start_time: existing_session.start_time + 30.minutes,
#               end_time:   existing_session.end_time   + 30.minutes)
#       end
#       it_behaves_like "rejects overlapping session"
#     end
#   end
#
# ---------------------------------------------------------------------------
# Exemplo de uso — conflito com CalendarBlock:
#
#   context "quando há CalendarBlock no horário" do
#     let!(:calendar_block) do
#       create(:calendar_block,
#              start_time: Time.current.beginning_of_hour + 14.hours,
#              end_time:   Time.current.beginning_of_hour + 16.hours)
#     end
#
#     subject do
#       build(:session,
#             start_time: calendar_block.start_time,
#             end_time:   calendar_block.end_time)
#     end
#     it_behaves_like "rejects session overlapping calendar block"
#   end
# ---------------------------------------------------------------------------

RSpec.shared_examples "rejects overlapping session" do
  it { is_expected.not_to be_valid }

  it "inclui mensagem de conflito de agenda nos erros" do
    subject.valid?
    error_messages = subject.errors.full_messages.join(" ")
    expect(error_messages).to match(/conflito|conflict|overlap|horário.*ocupado/i)
  end
end

RSpec.shared_examples "rejects session overlapping calendar block" do
  it { is_expected.not_to be_valid }

  it "inclui mensagem de bloqueio de calendário nos erros" do
    subject.valid?
    error_messages = subject.errors.full_messages.join(" ")
    expect(error_messages).to match(/bloqueio|block|indisponível|unavailable/i)
  end
end

# ---------------------------------------------------------------------------
# Shared example combinado — testa os 4 padrões de sobreposição temporal.
#
# CONTRATO:
#   let(:base_start) { Time.current.beginning_of_hour + 10.hours }
#   let(:base_end)   { Time.current.beginning_of_hour + 11.hours }
#   let(:factory_name) { :session }  # ou :calendar_block
#   let(:existing_record) { create(factory_name, start_time: base_start, end_time: base_end) }
# ---------------------------------------------------------------------------

RSpec.shared_examples "validates all overlap patterns" do
  # Garante que o registro existente está no banco antes dos testes
  before { existing_record }

  context "quando inicia dentro do intervalo existente" do
    subject do
      build(factory_name,
            start_time: base_start + 30.minutes,
            end_time:   base_end   + 30.minutes)
    end

    it_behaves_like "rejects overlapping session"
  end

  context "quando termina dentro do intervalo existente" do
    subject do
      build(factory_name,
            start_time: base_start - 30.minutes,
            end_time:   base_start + 30.minutes)
    end

    it_behaves_like "rejects overlapping session"
  end

  context "quando engloba o intervalo existente" do
    subject do
      build(factory_name,
            start_time: base_start - 15.minutes,
            end_time:   base_end   + 15.minutes)
    end

    it_behaves_like "rejects overlapping session"
  end

  context "quando é idêntico ao intervalo existente" do
    subject do
      build(factory_name,
            start_time: base_start,
            end_time:   base_end)
    end

    it_behaves_like "rejects overlapping session"
  end

  context "quando está imediatamente antes (sem sobreposição)" do
    subject do
      build(factory_name,
            start_time: base_start - 1.hour,
            end_time:   base_start)
    end

    it { is_expected.to be_valid }
  end

  context "quando está imediatamente depois (sem sobreposição)" do
    subject do
      build(factory_name,
            start_time: base_end,
            end_time:   base_end + 1.hour)
    end

    it { is_expected.to be_valid }
  end
end
