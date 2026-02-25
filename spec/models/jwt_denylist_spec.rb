require 'rails_helper'

RSpec.describe JwtDenylist, type: :model do
  describe "table name" do
    it "usa a tabela jwt_denylists" do
      expect(described_class.table_name).to eq("jwt_denylists")
    end
  end

  describe "revogação via Devise::JWT::RevocationStrategies::Denylist" do
    it "inclui a estratégia de revogação do Devise JWT" do
      expect(described_class.ancestors).to include(Devise::JWT::RevocationStrategies::Denylist)
    end
  end

  describe "criação de registro" do
    it "é válido com jti e exp" do
      entry = create(:jwt_denylist)
      expect(entry).to be_persisted
    end

    it "permite múltiplos registros com jti distintos" do
      create(:jwt_denylist)
      expect { create(:jwt_denylist) }.to change(JwtDenylist, :count).by(1)
    end
  end

  describe "limpeza de tokens expirados" do
    let!(:expired_token)  { create(:jwt_denylist, :expired) }
    let!(:valid_token)    { create(:jwt_denylist, exp: 30.minutes.from_now) }

    it "registra tokens expirados no banco" do
      expect(JwtDenylist.where("exp < ?", Time.current)).to include(expired_token)
    end

    it "não inclui tokens ainda válidos como expirados" do
      expect(JwtDenylist.where("exp < ?", Time.current)).not_to include(valid_token)
    end

    it "pode deletar todos os expirados em massa" do
      expect {
        JwtDenylist.where("exp < ?", Time.current).delete_all
      }.to change(JwtDenylist, :count).by(-1)
    end
  end
end
