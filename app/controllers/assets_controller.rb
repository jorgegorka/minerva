class AssetsController < ApplicationController
  before_action :set_asset, only: %i[show edit update destroy]
  before_action :set_categories, only: %i[new create edit update]

  def index
    @assets = Asset.includes(:category).order(created_at: :desc)
  end

  def show
  end

  def new
    @asset = Asset.new
  end

  def create
    @asset = Asset.new(asset_params)

    if @asset.save
      redirect_to @asset, notice: "Asset was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @asset.update(asset_params)
      redirect_to @asset, notice: "Asset was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @asset.destroy

    respond_to do |format|
      format.turbo_stream do
        # If the request comes from the show page, redirect to index
        if request.referer&.include?(asset_path(@asset))
          redirect_to assets_url, notice: "Asset was successfully deleted."
        else
          # Otherwise render the turbo stream (for index page deletion)
          render :destroy
        end
      end
      format.html { redirect_to assets_url, notice: "Asset was successfully deleted." }
    end
  end

  private

  def set_asset
    @asset = Asset.find(params[:id])
  end

  def set_categories
    @categories = Category.all.pluck :id, :title
  end

  def asset_params
    params.require(:asset).permit(:title, :file, :category_id)
  end
end
