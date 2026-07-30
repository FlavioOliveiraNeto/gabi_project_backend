require 'rails_helper'

RSpec.describe EncryptionConfig do
  let(:valid_source) do
    {
      "AR_ENCRYPTION_PRIMARY_KEY"         => "p" * 32,
      "AR_ENCRYPTION_DETERMINISTIC_KEY"   => "d" * 32,
      "AR_ENCRYPTION_KEY_DERIVATION_SALT" => "s" * 32
    }
  end

  describe ".fetch! fora de produção" do
    it "usa os defaults de desenvolvimento quando o ambiente está vazio" do
      keys = described_class.fetch!(env: "development", source: {})

      expect(keys).to eq(described_class::DEVELOPMENT_DEFAULTS)
    end

    it "prefere os valores do ambiente quando presentes" do
      keys = described_class.fetch!(env: "development", source: valid_source)

      expect(keys[:primary_key]).to eq("p" * 32)
    end

    it "não levanta erro em teste sem variáveis configuradas" do
      expect { described_class.fetch!(env: "test", source: {}) }.not_to raise_error
    end
  end

  describe ".fetch! em produção" do
    it "aceita chaves válidas" do
      keys = described_class.fetch!(env: "production", source: valid_source)

      expect(keys).to eq(
        primary_key:         "p" * 32,
        deterministic_key:   "d" * 32,
        key_derivation_salt: "s" * 32
      )
    end

    described_class::KEYS.each do |name, var|
      context "quando #{var} está ausente" do
        it "aborta o boot" do
          source = valid_source.except(var)

          expect { described_class.fetch!(env: "production", source: source) }
            .to raise_error(described_class::Error, /#{var} não configurada/)
        end
      end

      context "quando #{var} está em branco" do
        it "aborta o boot" do
          source = valid_source.merge(var => "   ")

          expect { described_class.fetch!(env: "production", source: source) }
            .to raise_error(described_class::Error, /#{var} não configurada/)
        end
      end

      context "quando #{var} usa o default de desenvolvimento" do
        it "aborta o boot em vez de cifrar com chave pública" do
          source = valid_source.merge(var => described_class::DEVELOPMENT_DEFAULTS.fetch(name))

          expect { described_class.fetch!(env: "production", source: source) }
            .to raise_error(described_class::Error, /valor de desenvolvimento/)
        end
      end

      context "quando #{var} é curta demais para AES-256-GCM" do
        it "aborta o boot" do
          source = valid_source.merge(var => "curta")

          expect { described_class.fetch!(env: "production", source: source) }
            .to raise_error(described_class::Error, /mínimo é 32/)
        end
      end
    end

    it "menciona o comando que gera chaves reais na mensagem de erro" do
      expect { described_class.fetch!(env: "production", source: {}) }
        .to raise_error(described_class::Error, /db:encryption:init/)
    end
  end

  describe "configuração efetiva da aplicação" do
    it "não usa nenhum default de desenvolvimento como chave ativa neste ambiente" do
      active = [
        Rails.application.config.active_record.encryption.primary_key,
        Rails.application.config.active_record.encryption.deterministic_key,
        Rails.application.config.active_record.encryption.key_derivation_salt
      ]

      expect(active).to all(be_present)
    end

    it "criptografa o conteúdo das notas clínicas de fato" do
      note = create(:clinical_note, content: "conteúdo sensível")

      raw = ClinicalNote.connection.select_value(
        "SELECT content FROM clinical_notes WHERE id = #{note.id}"
      )

      expect(raw).not_to include("conteúdo sensível")
    end
  end
end
