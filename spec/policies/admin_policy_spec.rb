require 'rails_helper'

RSpec.describe TherapistPolicy do
  subject(:policy) { described_class }

  let(:therapist)  { create(:user, role: :therapist) }
  let(:client) { create(:user, role: :client) }

  permissions :index? do
    it "permite acesso para therapist" do
      expect(policy).to permit(therapist, :therapist)
    end

    it "bloqueia acesso para client" do
      expect(policy).not_to permit(client, :therapist)
    end
  end
end
