# Shared examples para respostas HTTP padrão da API.
#
# Convenção de uso:
#   it_behaves_like "returns unauthorized"
#   it_behaves_like "returns not found"
#
# ATENÇÃO: json_response usa symbolize_names: true.
# As chaves são símbolos — use :error, :errors, :data (não strings).
#
# Shared examples de autenticação estão em:
#   spec/support/shared_examples/authenticated_endpoint.rb

RSpec.shared_examples "returns unauthorized" do
  it "retorna status 401 Unauthorized" do
    expect(response).to have_http_status(:unauthorized)
  end

  it "retorna body com chave :error" do
    expect(json_response).to include(:error)
  end
end

RSpec.shared_examples "returns forbidden" do
  it "retorna status 403 Forbidden" do
    expect(response).to have_http_status(:forbidden)
  end

  it "retorna body com chave :error" do
    expect(json_response).to include(:error)
  end
end

RSpec.shared_examples "returns not found" do
  it "retorna status 404 Not Found" do
    expect(response).to have_http_status(:not_found)
  end

  it "retorna body com chave :error" do
    expect(json_response).to include(:error)
  end
end

RSpec.shared_examples "returns unprocessable entity" do
  it "retorna status 422 Unprocessable Entity" do
    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "retorna body com chave :errors" do
    expect(json_response).to include(:errors)
  end
end

RSpec.shared_examples "returns success" do
  it "retorna status 200 OK" do
    expect(response).to have_http_status(:ok)
  end
end

RSpec.shared_examples "returns created" do
  it "retorna status 201 Created" do
    expect(response).to have_http_status(:created)
  end
end
