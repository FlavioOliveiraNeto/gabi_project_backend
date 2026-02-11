require 'rails_helper'

RSpec.describe User, type: :model do
  it "é válido com dados corretos" do
    expect(build(:user)).to be_valid
  end

  it "possui muitas anotações clínicas" do
    user = create(:user)
    create(:clinical_note, user: user)
    create(:clinical_note, user: user)
    
    expect(user.clinical_notes.count).to eq(2)
  end

  it "deleta as anotações se o usuário for deletado" do
    user = create(:user)
    create(:clinical_note, user: user)
    
    expect { user.destroy }.to change(ClinicalNote, :count).by(-1)
  end
end