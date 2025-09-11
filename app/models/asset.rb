class Asset < Document
  validate :file_presence

  private

  def file_presence
    errors.add(:file, "must be present") if !file.attached?
  end
end
