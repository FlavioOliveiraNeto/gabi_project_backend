require 'rails_helper'

RSpec.describe JwtDenylist, type: :model do
  describe "configuração do model" do
    it "usa a tabela jwt_denylists" do
      expect(described_class.table_name).to eq("jwt_denylists")
    end

    it "inclui Devise::JWT::RevocationStrategies::Denylist" do
      expect(described_class.ancestors).to include(Devise::JWT::RevocationStrategies::Denylist)
    end
  end

  describe "persistência" do
    it "é válido com jti e exp" do
      entry = create(:jwt_denylist)
      expect(entry).to be_persisted
    end

    it "permite múltiplos registros com jti distintos" do
      create(:jwt_denylist)
      expect { create(:jwt_denylist) }.to change(JwtDenylist, :count).by(1)
    end
  end

  describe ".revoke_jwt" do
    let(:payload) { { "jti" => SecureRandom.uuid, "exp" => 30.minutes.from_now.to_i } }
    let(:user) { create(:user, :client) }

    it "cria um registro na denylist com o jti e exp do payload" do
      expect {
        described_class.revoke_jwt(payload, user)
      }.to change(JwtDenylist, :count).by(1)

      entry = JwtDenylist.last
      expect(entry.jti).to eq(payload["jti"])
      expect(entry.exp.to_i).to eq(payload["exp"])
    end

    it "é idempotente: chamadas repetidas com o mesmo jti não duplicam o registro" do
      described_class.revoke_jwt(payload, user)
      expect {
        described_class.revoke_jwt(payload, user)
      }.not_to change(JwtDenylist, :count)
    end
  end

  describe ".jwt_revoked?" do
    let(:payload) { { "jti" => SecureRandom.uuid, "exp" => 30.minutes.from_now.to_i } }
    let(:user) { create(:user, :client) }

    context "quando o jti não está na denylist" do
      it "retorna false" do
        expect(described_class.jwt_revoked?(payload, user)).to be(false)
      end
    end

    context "quando o jti está na denylist" do
      before { described_class.revoke_jwt(payload, user) }

      it "retorna true" do
        expect(described_class.jwt_revoked?(payload, user)).to be(true)
      end
    end
  end

  describe "limpeza de tokens expirados" do
    let!(:expired_token) { create(:jwt_denylist, :expired) }
    let!(:valid_token)   { create(:jwt_denylist, exp: 30.minutes.from_now) }

    it "pode deletar todos os expirados em massa sem afetar os válidos" do
      expect {
        JwtDenylist.where("exp < ?", Time.current).delete_all
      }.to change(JwtDenylist, :count).by(-1)

      expect(JwtDenylist.exists?(valid_token.id)).to be(true)
    end
  end
end
