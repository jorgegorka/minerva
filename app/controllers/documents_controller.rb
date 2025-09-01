class DocumentsController < ApplicationController
  before_action :set_document, only: %i[show edit update destroy]

  def index
    @documents = Document.all.order(created_at: :desc)
  end

  def show
  end

  def new
    @document = Document.new
  end

  def create
    @document = Document.new(document_params)

    if @document.save
      redirect_to @document, notice: "Document was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @document.update(document_params)
      redirect_to @document, notice: "Document was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @document.destroy

    respond_to do |format|
      format.turbo_stream do
        # If the request comes from the show page, redirect to index
        if request.referer&.include?(document_path(@document))
          redirect_to documents_url, notice: "Document was successfully deleted."
        else
          # Otherwise render the turbo stream (for index page deletion)
          render :destroy
        end
      end
      format.html { redirect_to documents_url, notice: "Document was successfully deleted." }
    end
  end

  private

  def set_document
    @document = Document.find(params[:id])
  end

  def document_params
    params.require(:document).permit(:title, :content, :file)
  end
end
