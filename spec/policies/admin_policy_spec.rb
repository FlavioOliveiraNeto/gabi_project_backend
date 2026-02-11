require 'rails_helper'

RSpec.describe AdminPolicy do
  subject(:policy) { described_class }

  let(:admin)  { create(:user, role: :admin) }
  let(:client) { create(:user, role: :client) }

  permissions :index? do
    it "permite acesso para admin" do
      expect(policy).to permit(admin, :admin)
    end

    it "bloqueia acesso para client" do
      expect(policy).not_to permit(client, :admin)
    end
  end
end
