class Clients::SessionsController < Clients::BaseController
  def index
    sessions = current_user.sessions
                           .order(scheduled_at: :desc)
                           .limit(page_limit)
                           .offset(page_offset)
                           .to_a
                           .reverse

    render json: sessions.map { |session|
      {
        id: session.id,
        scheduled_at: session.scheduled_at,
        date: session.scheduled_at&.to_date&.iso8601,
        time: session.scheduled_at&.strftime("%H:%M"),
        status: session.status,
        status_label: I18n.t("session.status.#{session.status}", default: session.status.titleize),
        session_type: session.session_type,
        google_meet_link: current_user.google_meet_link,
        created_at: session.created_at,
        updated_at: session.updated_at
      }
    }
  end
end
