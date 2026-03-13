# frozen_string_literal: true

class Therapists::RecurringSchedulesController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_therapist!
  before_action :set_client
  before_action :set_schedule, only: %i[show update destroy]

  # GET /therapists/clients/:client_id/recurring_schedules
  def index
    render json: @client.recurring_schedules.active, status: :ok
  end

  # GET /therapists/clients/:client_id/recurring_schedules/:id
  def show
    render json: @schedule, status: :ok
  end

  # POST /therapists/clients/:client_id/recurring_schedules
  def create
    schedule = @client.recurring_schedules.build(schedule_params)

    if schedule.save
      render json: schedule, status: :created
    else
      render json: { errors: schedule.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /therapists/clients/:client_id/recurring_schedules/:id
  def update
    if @schedule.update(schedule_params)
      render json: @schedule, status: :ok
    else
      render json: { errors: @schedule.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /therapists/clients/:client_id/recurring_schedules/:id
  def destroy
    @schedule.update!(active: false)
    head :no_content
  end

  private

  def ensure_therapist!
    render json: { error: "Acesso restrito a terapeutas." }, status: :forbidden unless current_user.therapist?
  end

  def set_client
    @client = current_user.patients.find(params[:client_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Cliente não encontrado." }, status: :not_found
  end

  def set_schedule
    @schedule = @client.recurring_schedules.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Agenda recorrente não encontrada." }, status: :not_found
  end

  def schedule_params
    params.require(:recurring_schedule).permit(:weekday, :start_time, :duration_minutes, :meet_link, :active)
  end
end
