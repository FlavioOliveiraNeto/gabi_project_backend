require 'rails_helper'

RSpec.describe MeetLinkValidatable, type: :model do
  describe "User#google_meet_link" do
    it_behaves_like "a meet link field" do
      subject(:record) { build(:user, :client) }

      let(:meet_link_attribute) { :google_meet_link }
    end
  end

  describe "RecurringSchedule#meet_link" do
    it_behaves_like "a meet link field" do
      subject(:record) { build(:recurring_schedule) }

      let(:meet_link_attribute) { :meet_link }
    end
  end

  describe "Session#meet_link" do
    it_behaves_like "a meet link field" do
      subject(:record) { build(:session) }

      let(:meet_link_attribute) { :meet_link }
    end
  end

  describe "cobertura dos campos de link" do
    it "valida todas as colunas *meet_link* existentes no schema" do
      columns_by_model = {
        User               => [ :google_meet_link ],
        RecurringSchedule  => [ :meet_link ],
        Session            => [ :meet_link ]
      }

      actual = [ User, RecurringSchedule, Session, CalendarBlock, ClinicalNote, PatientNote, WeeklySchedule ]
               .to_h { |model| [ model, model.column_names.grep(/meet_link/).map(&:to_sym) ] }
               .reject { |_model, columns| columns.empty? }

      expect(actual).to eq(columns_by_model),
        "Há coluna de meet_link sem validação de host. Inclua MeetLinkValidatable " \
        "no model e declare validates_meet_link, depois atualize este spec."
    end
  end
end
