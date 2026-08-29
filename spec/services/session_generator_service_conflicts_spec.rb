require 'rails_helper'

RSpec.describe SessionGeneratorService, "acúmulo de conflitos" do
  let(:therapist) { create(:user, :therapist) }
  let(:patient)   { create(:user, :client, therapist: therapist) }
  let(:other)     { create(:user, :client, therapist: therapist) }

  subject(:service) { described_class.new(therapist) }

  around { |ex| travel_to(Time.zone.local(2026, 3, 2, 9, 0)) { ex.run } }

  let!(:occupied) do
    create(:session, :scheduled, user: other,
           scheduled_at: Time.zone.local(2026, 3, 7, 14, 0),
           start_time:   Time.zone.local(2026, 3, 7, 14, 0),
           end_time:     Time.zone.local(2026, 3, 7, 14, 50))
  end

  before do
    create(:weekly_schedule, user: patient, weekday: :saturday,  time: "14:30")
    create(:weekly_schedule, user: patient, weekday: :wednesday, time: "14:30")
  end

  it "começa com #conflicts vazio" do
    expect(service.conflicts).to eq([])
  end

  it "registra o slot que não pôde ser criado em vez de silenciar" do
    service.generate_for_patient(patient)

    expect(service.conflicts).to be_present
    expect(service.conflicts.first).to include(
      patient_id: patient.id,
      weekday:    "saturday",
      time:       "14:30"
    )
  end

  it "informa o motivo e o paciente que já ocupava o horário" do
    service.generate_for_patient(patient)

    conflict = service.conflicts.first
    expect(conflict[:scheduled_at]).to eq(Time.zone.local(2026, 3, 7, 14, 30))
    expect(conflict[:reason]).to be_present
  end

  it "não duplica o mesmo slot semanal em vários conflitos" do
    service.generate_for_patient(patient)

    expect(service.conflicts.map { |c| [ c[:weekday], c[:time] ] }.uniq.size)
      .to eq(service.conflicts.size)
  end

  it "ainda gera as sessões dos slots livres (o job noturno não deve parar)" do
    service.generate_for_patient(patient)

    expect(patient.sessions.recurring.where("EXTRACT(DOW FROM start_time) = 3")).to be_present
  end

  it "não registra conflito quando não há choque" do
    occupied.destroy
    service.generate_for_patient(patient)

    expect(service.conflicts).to be_empty
  end

  describe "#generate_for_current_and_next_month" do
    it "acumula conflitos de todos os pacientes sem levantar exceção" do
      expect { service.generate_for_current_and_next_month }.not_to raise_error
      expect(service.conflicts).to be_present
    end
  end
end
