class TextsController < ApplicationController
  before_action :set_text, only: %i[show edit update destroy]
  before_action :set_categories, only: %i[new create edit update]

  def index
    @texts = Text.includes(:category).order(created_at: :desc)
  end

  def show
  end

  def new
    @text = Text.new
  end

  def create
    @text = Text.new(text_params)

    if @text.save
      redirect_to @text, notice: "Text was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @text.update(text_params)
      redirect_to @text, notice: "Text was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @text.destroy

    respond_to do |format|
      format.turbo_stream do
        # If the request comes from the show page, redirect to index
        if request.referer&.include?(text_path(@text))
          redirect_to texts_url, notice: "Text was successfully deleted."
        else
          # Otherwise render the turbo stream (for index page deletion)
          render :destroy
        end
      end
      format.html { redirect_to texts_url, notice: "Text was successfully deleted." }
    end
  end

  private

  def set_text
    @text = Text.find(params[:id])
  end

  def set_categories
    @categories = Category.all.pluck :id, :title
  end

  def text_params
    params.require(:text).permit(:title, :content, :category_id)
  end
end
