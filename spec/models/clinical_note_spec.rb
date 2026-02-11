require 'rails_helper'

RSpec.describe ClinicalNote, type: :model do
  it "é válido com conteúdo e usuário" do
    expect(build(:clinical_note)).to be_valid
  end

  it "é inválido sem conteúdo" do
    note = build(:clinical_note, content: nil)
    expect(note).not_to be_valid
  end
end