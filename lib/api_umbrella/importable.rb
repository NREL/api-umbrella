module ApiUmbrella
  module Importable
    extend ActiveSupport::Concern

    included do
      attr_accessible :_id, :_import_id,
        :as => [:importer]
    end

    def _import_id=(id)
      logger.info("SETTING _import_id")
      self.id = id
    end

    def import_nested_attributes(data, options = {})
      import_data = self.class.importify_attributes(data)
      self.assign_attributes(data, :without_protection => true)
      self.updated_at = Time.now
    end

    module ClassMethods
      def importify_attributes(object)
        duplicate = if(object.duplicable?) then object.dup else object end

        if(duplicate.kind_of?(Hash))
          id_key = (duplicate.keys & ["_id", "id", :_id, :id]).first
          if(id_key.present?)
            duplicate["_import_id"] = duplicate.delete(id_key)
          end

          duplicate.each do |key, value|
            duplicate[key] = importify_attributes(value)
          end
        elsif(duplicate.kind_of?(Array))
          duplicate.map! do |item|
            importify_attributes(item)
          end
        end

        duplicate
      end
    end
  end
end
