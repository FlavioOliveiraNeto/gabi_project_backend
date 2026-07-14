require "webmock/rspec"

# Desabilita conexões HTTP reais durante os testes.
# allow_localhost: true permite que request specs chamem o próprio servidor Rack.
WebMock.disable_net_connect!(allow_localhost: true)
