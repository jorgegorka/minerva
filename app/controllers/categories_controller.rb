class CategoriesController < ApplicationController
  before_action :set_category, only: %i[edit update destroy]

  def index
    @categories = Category.all.order(created_at: :desc)
  end

  def new
    @category = Category.new
  end

  def create
    @category = Category.new(category_params)

    if @category.save
      redirect_to categories_url, notice: "Category was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @category.update(category_params)
      redirect_to categories_url, notice: "Category was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @category.destroy

    respond_to do |format|
      format.turbo_stream do
        # If the request comes from the show page, redirect to index
        if request.referer&.include?(category_path(@category))
          redirect_to categories_url, notice: "Category was successfully deleted."
        else
          # Otherwise render the turbo stream (for index page deletion)
          render :destroy
        end
      end
      format.html { redirect_to categories_url, notice: "Category was successfully deleted." }
    end
  end

  private

  def set_category
    @category = Category.find(params[:id])
  end

  def category_params
    params.require(:category).permit(:title)
  end
end
