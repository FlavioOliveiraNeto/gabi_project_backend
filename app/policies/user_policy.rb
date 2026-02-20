class UserPolicy < ApplicationPolicy
  def show?
    user.therapist? && record.therapist_id == user.id
  end

  def update?
    show?
  end

  def destroy?
    show?
  end
end