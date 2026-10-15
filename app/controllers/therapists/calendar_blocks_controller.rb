class Therapists::CalendarBlocksController < Therapists::BaseController
  before_action :set_block, only: %i[show update destroy]

  def index
    blocks = current_user.calendar_blocks.upcoming.order(:start_time)
    render json: blocks.map { |b| block_json(b) }, status: :ok
  end

  def show
    render json: block_json(@block), status: :ok
  end

  def create
    block = current_user.calendar_blocks.new(block_params)

    if block.save
      render json: block_json(block), status: :created
    else
      render json: { errors: block.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def update
    if @block.update(block_params)
      render json: block_json(@block), status: :ok
    else
      render json: { errors: @block.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @block.destroy
    head :no_content
  end

  private

  def set_block
    @block = current_user.calendar_blocks.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Bloqueio de agenda não encontrado." }, status: :not_found
  end

  def block_json(block)
    block.as_json(only: %i[id start_time end_time reason created_at updated_at])
  end

  def block_params
    params.require(:calendar_block).permit(:start_time, :end_time, :reason)
  end
end
