require 'rails_helper'

RSpec.describe JwtRevocation do
  let(:user) { create(:user, :client) }

  def payload_for(user, jti: SecureRandom.uuid, version: user.token_version)
    {
      "sub"                        => user.id.to_s,
      "jti"                        => jti,
      "exp"                        => 30.minutes.from_now.to_i,
      described_class::VERSION_CLAIM => version
    }
  end

  describe ".jwt_revoked?" do
    context "com token corrente e versão atual" do
      it "não considera revogado" do
        expect(described_class.jwt_revoked?(payload_for(user), user)).to be false
      end
    end

    context "camada 1 — denylist (logout de um token)" do
      it "considera revogado quando o jti está na denylist" do
        payload = payload_for(user)
        described_class.revoke_jwt(payload, user)

        expect(described_class.jwt_revoked?(payload, user)).to be true
      end

      it "não afeta os outros tokens do mesmo usuário" do
        revoked = payload_for(user)
        other   = payload_for(user)
        described_class.revoke_jwt(revoked, user)

        expect(described_class.jwt_revoked?(other, user)).to be false
      end
    end

    context "camada 2 — token_version (revogação em massa)" do
      it "considera revogado quando a versão do payload é anterior à do usuário" do
        payload = payload_for(user, version: user.token_version)
        user.revoke_all_jwts!

        expect(described_class.jwt_revoked?(payload, user.reload)).to be true
      end

      it "considera revogado quando a versão do payload é posterior à do usuário" do
        payload = payload_for(user, version: user.token_version + 5)

        expect(described_class.jwt_revoked?(payload, user)).to be true
      end

      it "aceita token legado sem o claim de versão enquanto token_version é 0" do
        payload = payload_for(user).except(described_class::VERSION_CLAIM)

        expect(described_class.jwt_revoked?(payload, user)).to be false
      end

      it "rejeita token legado sem o claim depois de uma revogação em massa" do
        payload = payload_for(user).except(described_class::VERSION_CLAIM)
        user.revoke_all_jwts!

        expect(described_class.jwt_revoked?(payload, user.reload)).to be true
      end
    end
  end

  describe ".revoke_jwt" do
    it "grava o jti na denylist" do
      payload = payload_for(user)

      expect { described_class.revoke_jwt(payload, user) }
        .to change(JwtDenylist, :count).by(1)
    end

    it "não incrementa token_version (revoga um token, não todos)" do
      expect { described_class.revoke_jwt(payload_for(user), user) }
        .not_to change { user.reload.token_version }
    end

    it "é idempotente para o mesmo jti" do
      payload = payload_for(user)
      described_class.revoke_jwt(payload, user)

      expect { described_class.revoke_jwt(payload, user) }
        .not_to change(JwtDenylist, :count)
    end
  end

  describe "contrato exigido pelo devise-jwt" do
    it "responde a jwt_revoked?" do
      expect(described_class).to respond_to(:jwt_revoked?)
    end

    it "responde a revoke_jwt" do
      expect(described_class).to respond_to(:revoke_jwt)
    end

    it "está configurada como a estratégia de revogação do User" do
      expect(User.jwt_revocation_strategy).to eq(described_class)
    end
  end
end
