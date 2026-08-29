RSpec.shared_examples "um campo de link de reunião" do
  def assign_meet_link(record, attribute, value)
    record.public_send("#{attribute}=", value)
    record
  end

  it "aceita nil" do
    assign_meet_link(record, meet_link_attribute, nil)

    expect(record).to be_valid
  end

  it "aceita string vazia" do
    assign_meet_link(record, meet_link_attribute, "")

    expect(record).to be_valid
  end

  it "aceita link HTTPS do Google Meet" do
    assign_meet_link(record, meet_link_attribute, "https://meet.google.com/abc-defg-hij")

    expect(record).to be_valid
  end

  it "aceita host em caixa alta" do
    assign_meet_link(record, meet_link_attribute, "https://MEET.GOOGLE.COM/abc-defg-hij")

    expect(record).to be_valid
  end

  it "rejeita HTTP" do
    assign_meet_link(record, meet_link_attribute, "http://meet.google.com/abc-defg-hij")

    expect(record).to be_invalid
    expect(record.errors[meet_link_attribute].join).to match(/HTTPS/)
  end

  it "rejeita host de terceiro" do
    assign_meet_link(record, meet_link_attribute, "https://evil.com/entrar")

    expect(record).to be_invalid
  end

  it "rejeita host que apenas parece o do Google Meet" do
    assign_meet_link(record, meet_link_attribute, "https://meet-google.evil.com/abc")

    expect(record).to be_invalid
  end

  it "rejeita host com o permitido como prefixo de outro domínio" do
    assign_meet_link(record, meet_link_attribute, "https://meet.google.com.evil.com/abc")

    expect(record).to be_invalid
  end

  it "rejeita subdomínio não listado" do
    assign_meet_link(record, meet_link_attribute, "https://evil.meet.google.com/abc")

    expect(record).to be_invalid
  end

  it "rejeita userinfo apontando para outro host" do
    assign_meet_link(record, meet_link_attribute, "https://meet.google.com@evil.com/abc")

    expect(record).to be_invalid
  end

  it "rejeita esquema javascript" do
    assign_meet_link(record, meet_link_attribute, "javascript:alert(document.cookie)")

    expect(record).to be_invalid
  end

  it "rejeita esquema data" do
    assign_meet_link(record, meet_link_attribute, "data:text/html;base64,PHNjcmlwdD4=")

    expect(record).to be_invalid
  end

  it "rejeita URL sem protocolo" do
    assign_meet_link(record, meet_link_attribute, "meet.google.com/abc-defg-hij")

    expect(record).to be_invalid
  end

  it "rejeita texto arbitrário" do
    assign_meet_link(record, meet_link_attribute, "link inválido")

    expect(record).to be_invalid
  end
end
