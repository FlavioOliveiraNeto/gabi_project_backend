# frozen_string_literal: true

class Therapists::CalendarBlocksController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_therapist!
  before_action :set_block, only: %i[show update destroy]

  # GET /therapists/calendar_blocks
  def index
    blocks = CalendarBlock.upcoming.order(:start_time)
    render json: blocks, status: :ok
  end

  # GET /therapists/calendar_blocks/:id
  def show
    render json: @block, status: :ok
  end

  # POST /therapists/calendar_blocks
  def create
    block = CalendarBlock.new(block_params)

    if block.save
      render json: block, status: :created
    else
      render json: { errors: block.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /therapists/calendar_blocks/:id
  def update
    if @block.update(block_params)
      render json: @block, status: :ok
    else
      render json: { errors: @block.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /therapists/calendar_blocks/:id
  def destroy
    @block.destroy
    head :no_content
  end

  private

  def ensure_therapist!
    render json: { error: "Acesso restrito a terapeutas." }, status: :forbidden unless current_user.therapist?
  end

  def set_block
    @block = CalendarBlock.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Bloqueio de agenda não encontrado." }, status: :not_found
  end

  def block_params
    params.require(:calendar_block).permit(:start_time, :end_time, :reason)
  end
end
