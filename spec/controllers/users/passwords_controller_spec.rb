require "rails_helper"

# Teste unitário do método privado Users::PasswordsController#revoke_current_jwt!
# Cobre a branch rescue JWT::DecodeError, inacessível em specs de request porque
# o mesmo token válido que autentica é o que o método tentaria decodificar.
RSpec.describe Users::PasswordsController, type: :controller do
  let(:therapist) { create(:user, :therapist) }
  let(:user)      { create(:user, :client, therapist: therapist) }

  before { allow(controller).to receive(:current_user).and_return(user) }

  describe "#revoke_current_jwt! (privado)" do
    subject(:revoke!) { controller.send(:revoke_current_jwt!) }

    context "quando JWT::DecodeError é levantado durante a decodificação do token" do
      before do
        request.cookies["auth_token"] = "token_qualquer"
        allow(JWT).to receive(:decode).and_raise(JWT::DecodeError)
      end

      it "não propaga a exceção" do
        expect { revoke! }.not_to raise_error
      end

      it "registra o erro no logger" do
        expect(Rails.logger).to receive(:error).with("Erro de decode do JWT.")
        revoke!
      end

      it "não insere entrada na denylist" do
        revoke!
        expect(JwtDenylist.count).to eq(0)
      end
    end

    context "quando nenhum token está presente (cookie e header ausentes)" do
      it "retorna sem levantar exceção" do
        expect { revoke! }.not_to raise_error
      end

      it "não toca a denylist" do
        revoke!
        expect(JwtDenylist.count).to eq(0)
      end
    end
  end
end
