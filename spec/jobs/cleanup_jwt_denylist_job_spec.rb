require 'rails_helper'

RSpec.describe CleanupJwtDenylistJob, type: :job do
  # .queue_name
  describe '.queue_name' do
    it 'é :default' do
      expect(described_class.queue_name).to eq('default')
    end
  end

  # #perform
  describe '#perform' do
    subject(:perform_job) { described_class.new.perform }

    context 'com tokens expirados e válidos' do
      let!(:expired_token1) { create(:jwt_denylist, :expired) }
      let!(:expired_token2) { create(:jwt_denylist, exp: 2.hours.ago) }
      let!(:valid_token)    { create(:jwt_denylist, exp: 30.minutes.from_now) }

      it 'remove tokens com exp no passado' do
        expect { perform_job }.to change(JwtDenylist, :count).by(-2)
      end

      it 'preserva tokens ainda válidos' do
        perform_job
        expect(valid_token.reload).to be_persisted
      end
    end

    context 'sem tokens expirados' do
      it 'não levanta erro' do
        expect { perform_job }.not_to raise_error
      end
    end

    context 'idempotência' do
      let!(:expired_token) { create(:jwt_denylist, :expired) }
      let!(:valid_token)   { create(:jwt_denylist, exp: 30.minutes.from_now) }

      it 'é seguro de executar múltiplas vezes' do
        2.times { described_class.new.perform }

        expect(JwtDenylist.where('exp < ?', Time.current).count).to eq(0)
        expect(JwtDenylist.count).to eq(1)
      end
    end

    context 'no limite de expiração' do
      it 'não remove token com exp igual a Time.current' do
        freeze_time do
          token = create(:jwt_denylist, exp: Time.current)

          perform_job

          expect(token.reload).to be_persisted
        end
      end
    end
  end
end
