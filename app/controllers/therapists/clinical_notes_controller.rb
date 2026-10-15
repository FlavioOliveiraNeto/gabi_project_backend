class Therapists::ClinicalNotesController < Therapists::BaseController
  before_action :set_patient
  before_action :set_note, only: %i[show update destroy]

  def index
    audit_read!("list_clinical_notes", "User", @patient.id)

    render json: @patient.clinical_notes
                         .where(therapist: current_user)
                         .order(created_at: :desc)
                         .limit(page_limit)
                         .offset(page_offset)
                         .as_json(only: %i[id content date created_at])
  end

  def create
    session = @patient.sessions.find_by(id: params[:session_id])
    return render json: { error: "Sessão não encontrada." }, status: :not_found unless session

    note = @patient.clinical_notes.build(
      session: session,
      content: params[:content],
      date: session.start_time,
      therapist: current_user
    )

    if note.save
      render json: note.as_json(only: %i[id content date created_at]), status: :created
    else
      render json: { errors: note.errors.full_messages }, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotUnique
    # Corrida de dois POSTs: a validação passa nos dois, o índice único barra um.
    render json: { errors: [ "Session já possui uma anotação clínica" ] }, status: :unprocessable_entity
  end

  def show
    audit_read!("read", "ClinicalNote", @note.id)

    render json: @note.as_json(only: %i[id content date created_at])
  end

  def update
    if @note.update(content: params[:content])
      render json: @note.as_json(only: %i[id content date created_at])
    else
      render json: { errors: @note.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @note.destroy
    head :no_content
  end

  private

  # Leitura de prontuário precisa ser rastreável (LGPD / CFP 001/2009).
  def audit_read!(action, entity_type, entity_id)
    AuditLog.create!(user: current_user, action: action, entity_type: entity_type, entity_id: entity_id)
  end


  def set_patient
    @patient = current_user.patients.find_by(id: params[:patient_id])
    render json: { error: "Paciente não encontrado." }, status: :not_found unless @patient
  end

  def set_note
    @note = @patient.clinical_notes.where(therapist: current_user).find_by(id: params[:id])
    render json: { error: "Nota não encontrada." }, status: :not_found unless @note
  end
end
