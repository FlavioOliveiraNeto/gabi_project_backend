require 'rails_helper'

RSpec.describe User, type: :model do
  it "é válido com dados corretos" do
    expect(build(:user)).to be_valid
  end

  it "define role client por padrão" do
    user = build(:user)

    expect(user.client?).to be true
    expect(user.admin?).to be false
  end
end
