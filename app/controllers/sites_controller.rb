class SitesController < ApplicationController
  before_action :set_site, only: %i[show edit update destroy]
  before_action :set_categories, only: %i[new create edit update]

  def index
    @sites = Site.includes(:category).order(created_at: :desc)
  end

  def show
  end

  def new
    @site = Site.new
  end

  def create
    @site = Site.new(site_params)

    if @site.save
      redirect_to @site, notice: "Site was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @site.update(site_params)
      redirect_to @site, notice: "Site was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @site.destroy

    respond_to do |format|
      format.turbo_stream do
        # If the request comes from the show page, redirect to index
        if request.referer&.include?(site_path(@site))
          redirect_to sites_url, notice: "Site was successfully deleted."
        else
          # Otherwise render the turbo stream (for index page deletion)
          render :destroy
        end
      end
      format.html { redirect_to sites_url, notice: "Site was successfully deleted." }
    end
  end

  private

  def set_site
    @site = Site.find(params[:id])
  end

  def set_categories
    @categories = Category.all.pluck :id, :title
  end

  def site_params
    params.require(:site).permit(:title, :url, :max_depth, :category_id)
  end
end
