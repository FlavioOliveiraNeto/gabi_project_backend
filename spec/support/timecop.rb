require "timecop"

RSpec.configure do |config|
  # Garante que o Timecop é sempre revertido após cada exemplo,
  # mesmo quando o spec usa Timecop.freeze/travel sem bloco.
  config.after(:each) do
    Timecop.return
  end
end
