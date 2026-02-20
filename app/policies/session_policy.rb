class SessionPolicy < ApplicationPolicy
  def update?
    user.therapist? && record.user.therapist_id == user.id
  end

  def show?
    record.user == user || record.user.therapist_id == user.id
  end
end