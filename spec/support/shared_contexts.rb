RSpec.shared_context "autenticado como terapeuta" do
  let(:therapist) { create(:user, :therapist) }
  let(:headers)   { auth_headers_for(therapist) }
end

RSpec.shared_context "autenticado como cliente" do
  let(:client)  { create(:user, :client) }
  let(:headers) { auth_headers_for(client) }
end
