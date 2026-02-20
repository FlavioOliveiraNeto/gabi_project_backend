class PatientNotePolicy < ApplicationPolicy
  def show?
    record.user == user
  end
end