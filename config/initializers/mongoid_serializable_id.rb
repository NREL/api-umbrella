module Mongoid
  module Document
    # Hide the fact that mongo uses '_id' as it's primary key from API outputs,
    # since this is an implementation detail we don't want to expose.
    def serializable_hash(*args)
      hash = super(*args)
      if(hash.key?('_id'))
        hash['id'] = hash.delete('_id')
      end

      hash
    end
  end
end
