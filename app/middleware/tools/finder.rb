module Tools
  class Finder
    class << self
      def call
        new.call
      end
    end

    def call
      [
        Tools::DocumentSearch.new
      ]
    end
  end
end
