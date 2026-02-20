class TherapistPolicy < ApplicationPolicy
  def index?
    user.therapist?
  end
end
