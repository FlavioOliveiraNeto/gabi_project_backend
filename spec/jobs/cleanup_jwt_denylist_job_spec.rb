require 'rails_helper'

RSpec.describe CleanupJwtDenylistJob, type: :job do
  describe "#perform" do
    let!(:expired_token1) { create(:jwt_denylist, :expired) }
    let!(:expired_token2) { create(:jwt_denylist, exp: 2.hours.ago) }
    let!(:valid_token)    { create(:jwt_denylist, exp: 30.minutes.from_now) }

    it "remove tokens com exp no passado" do
      expect {
        described_class.new.perform
      }.to change(JwtDenylist, :count).by(-2)
    end

    it "preserva tokens ainda válidos" do
      described_class.new.perform
      expect(valid_token.reload).to be_persisted
    end

    it "não falha quando não há tokens expirados" do
      JwtDenylist.where("exp < ?", Time.current).delete_all

      expect { described_class.new.perform }.not_to raise_error
    end

    context "idempotência" do
      it "é seguro de executar múltiplas vezes" do
        2.times { described_class.new.perform }

        expired_count = JwtDenylist.where("exp < ?", Time.current).count
        expect(expired_count).to eq(0)
        expect(JwtDenylist.count).to eq(1) # apenas o válido permanece
      end
    end

    it "usa a fila :default" do
      expect(described_class.queue_name).to eq("default")
    end
  end
end
