require 'rails_helper'

RSpec.describe WeeklySchedule, type: :model do
  describe "associações" do
    it { is_expected.to belong_to(:user) }
  end

  describe "validações" do
    it "é válido com dados corretos" do
      expect(build(:weekly_schedule)).to be_valid
    end

    it { is_expected.to validate_presence_of(:weekday) }
    it { is_expected.to validate_presence_of(:effective_from) }
    it { is_expected.to validate_presence_of(:time) }

    describe "formato de time" do
      it "é válido com 09:00" do
        expect(build(:weekly_schedule, time: "09:00")).to be_valid
      end

      it "é válido com 23:59" do
        expect(build(:weekly_schedule, time: "23:59")).to be_valid
      end

      it "é inválido com hora acima de 23 (25:00)" do
        expect(build(:weekly_schedule, time: "25:00")).not_to be_valid
      end

      it "é inválido sem zero à esquerda na hora (9:00)" do
        expect(build(:weekly_schedule, time: "9:00")).not_to be_valid
      end

      it "é inválido com letras no lugar da hora" do
        expect(build(:weekly_schedule, time: "abc")).not_to be_valid
      end

      it "é inválido com string vazia" do
        expect(build(:weekly_schedule, time: "")).not_to be_valid
      end
    end

    describe "effective_until" do
      it "é válido com effective_until nil (schedule aberto)" do
        expect(build(:weekly_schedule, effective_until: nil)).to be_valid
      end

      it "é válido com effective_until posterior a effective_from" do
        schedule = build(:weekly_schedule,
          effective_from:  Date.current,
          effective_until: Date.current + 30.days
        )
        expect(schedule).to be_valid
      end

      it "é válido com effective_until igual a effective_from" do
        schedule = build(:weekly_schedule,
          effective_from:  Date.current,
          effective_until: Date.current
        )
        expect(schedule).to be_valid
      end

      it "é inválido quando effective_until < effective_from" do
        schedule = build(:weekly_schedule,
          effective_from:  Date.current,
          effective_until: Date.current - 1.day
        )
        expect(schedule).not_to be_valid
        expect(schedule.errors[:effective_until]).to be_present
      end
    end
  end

  describe "enums" do
    it {
      is_expected.to define_enum_for(:weekday).with_values(
        sunday: 0, monday: 1, tuesday: 2, wednesday: 3,
        thursday: 4, friday: 5, saturday: 6
      )
    }
  end

  describe "scopes" do
    let!(:active_schedule) do
      create(:weekly_schedule, effective_from: 1.week.ago.to_date, effective_until: nil)
    end
    let!(:closed_schedule) { create(:weekly_schedule, :expired) }
    let!(:future_schedule) { create(:weekly_schedule, :future) }

    describe ".active" do
      # o dia do fechamento ainda conta como ativo (usa >=)
      let!(:closing_today_schedule) do
        create(:weekly_schedule,
          effective_from:  1.month.ago.to_date,
          effective_until: Date.current
        )
      end

      it "retorna schedules ativos hoje" do
        expect(WeeklySchedule.active).to include(active_schedule)
      end

      it "não retorna schedules expirados" do
        expect(WeeklySchedule.active).not_to include(closed_schedule)
      end

      it "não retorna schedules com vigência futura" do
        expect(WeeklySchedule.active).not_to include(future_schedule)
      end

      it "inclui schedule cujo effective_until é hoje (último dia de vigência)" do
        expect(WeeklySchedule.active).to include(closing_today_schedule)
      end
    end

    describe ".effective_on(date)" do
      it "retorna schedule ativo na data informada" do
        # closed_schedule cobre 2020-01-01 a 2020-12-31 (trait :expired); data relativa cairia em 2026
        expect(WeeklySchedule.effective_on(Date.new(2020, 6, 15))).to include(closed_schedule)
      end

      it "retorna schedule futuro quando a data é futura" do
        expect(WeeklySchedule.effective_on(2.months.from_now.to_date)).to include(future_schedule)
      end

      it "retorna schedule ativo para Date.current" do
        expect(WeeklySchedule.effective_on(Date.current)).to include(active_schedule)
      end

      it "retorna lista vazia quando nenhum schedule está vigente na data" do
        data_sem_schedule = Date.new(2000, 1, 1)
        expect(WeeklySchedule.effective_on(data_sem_schedule)).to be_empty
      end
    end

    describe ".overlapping(start_date, end_date)" do
      it "retorna schedules que se sobrepõem ao intervalo" do
        # Intervalo de 2020-01-01 até 2 meses no futuro cobre closed_schedule (2020), active e future
        result = WeeklySchedule.overlapping(Date.new(2020, 1, 1), 2.months.from_now.to_date)
        expect(result).to include(active_schedule, closed_schedule, future_schedule)
      end

      it "não retorna schedules fora do intervalo" do
        result = WeeklySchedule.overlapping(5.years.from_now.to_date, 6.years.from_now.to_date)
        expect(result).to be_empty
      end

      # Schedule aberto (effective_until nil) usa COALESCE(effective_until, Date.current).
      # Isso significa que ele não aparece em intervalos inteiramente no futuro.
      it "não inclui schedule aberto (effective_until nil) em intervalo inteiramente futuro" do
        result = WeeklySchedule.overlapping(1.year.from_now.to_date, 2.years.from_now.to_date)
        expect(result).not_to include(active_schedule)
      end
    end
  end

  describe "#active?" do
    it "retorna true para schedule sem effective_until" do
      schedule = build(:weekly_schedule, effective_from: 1.week.ago.to_date, effective_until: nil)
      expect(schedule.active?).to be true
    end

    it "retorna true para schedule com effective_until no futuro" do
      schedule = build(:weekly_schedule,
        effective_from:  1.week.ago.to_date,
        effective_until: 1.week.from_now.to_date
      )
      expect(schedule.active?).to be true
    end

    it "retorna false para schedule expirado" do
      expect(build(:weekly_schedule, :expired).active?).to be false
    end

    it "retorna false para schedule ainda não iniciado" do
      expect(build(:weekly_schedule, :future).active?).to be false
    end

    it "retorna true quando effective_from é hoje (primeiro dia de vigência)" do
      schedule = build(:weekly_schedule, effective_from: Date.current, effective_until: nil)
      expect(schedule.active?).to be true
    end

    it "retorna true quando effective_until é hoje (último dia de vigência)" do
      schedule = build(:weekly_schedule,
        effective_from:  1.month.ago.to_date,
        effective_until: Date.current
      )
      expect(schedule.active?).to be true
    end
  end

  describe "#close!(until_date)" do
    it "define effective_until e persiste no banco" do
      schedule   = create(:weekly_schedule)
      until_date = 5.days.from_now.to_date
      schedule.close!(until_date)
      expect(schedule.reload.effective_until).to eq(until_date)
    end

    it "torna o schedule inativo depois do fechamento no passado" do
      schedule = create(:weekly_schedule, effective_from: 1.week.ago.to_date)
      schedule.close!(Date.current - 1.day)
      expect(schedule.reload.active?).to be false
    end
  end
end
