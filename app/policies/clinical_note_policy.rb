class ClinicalNotePolicy < ApplicationPolicy
  def show?
    user.therapist? && record.user.therapist_id == user.id
  end
end