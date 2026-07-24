require "rails_helper"

RSpec.describe "Reset password email", type: :mailer do
  let(:user) { create(:user, :client, name: "Ana Beatriz", email: "ana@example.com") }

  before { ActiveJob::Base.queue_adapter = :test }

  def deliver
    ActionMailer::Base.deliveries.clear
    token = user.send_reset_password_instructions
    [ token, ActionMailer::Base.deliveries.last ]
  end

  it "delivers exactly one email to the user" do
    _token, mail = deliver
    expect(ActionMailer::Base.deliveries.size).to eq(1)
    expect(mail.to).to eq([ "ana@example.com" ])
  end

  it "sends from the configured mailer_sender (MAIL_FROM)" do
    _token, mail = deliver
    expect(mail.from).to eq([ Devise.mailer_sender ])
  end

  def decoded_bodies(mail)
    [ mail.html_part, mail.text_part ].compact.map { |p| p.body.decoded }
  end

  it "links to the FRONTEND reset page with the raw token, not the backend" do
    token, mail = deliver
    frontend = ENV.fetch("FRONTEND_URL", "http://localhost:5173")
    expected = "#{frontend}/reset-senha?token=#{token}"

    decoded_bodies(mail).each do |body|
      expect(body).to include(expected)
      expect(body).not_to include("localhost:3000")
    end
  end

  it "addresses the user by first name" do
    _token, mail = deliver
    expect(decoded_bodies(mail)).to all(include("Ana"))
  end
end
