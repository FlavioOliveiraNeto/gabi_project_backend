module MeetLinkValidatable
  extend ActiveSupport::Concern

  ALLOWED_MEET_HOSTS = %w[meet.google.com].freeze

  class_methods do
    def validates_meet_link(attribute)
      validate -> { validate_meet_link(attribute) }, if: -> { self[attribute].present? }
    end
  end

  private

  def validate_meet_link(attribute)
    uri = URI.parse(self[attribute].to_s)

    unless uri.is_a?(URI::HTTPS)
      errors.add(attribute, "deve usar HTTPS")
      return
    end

    unless ALLOWED_MEET_HOSTS.include?(uri.host&.downcase)
      errors.add(attribute, "deve ser uma URL de #{ALLOWED_MEET_HOSTS.join(', ')}")
    end
  rescue URI::InvalidURIError
    errors.add(attribute, "não é uma URL válida")
  end
end
