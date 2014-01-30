module ActiveRecord
  module Persistence
    def update_columns(attributes)
      raise ActiveRecordError, "cannot update on a new record object" unless persisted?

      attributes.each_key do |key|
        verify_readonly_attribute(key.to_s)
      end

      # wakaru changes start
      if self.class.columns_hash.keys.include?(partition_key)
        updated_count = self.class.unscoped.where(self.class.primary_key => id,
                                                  partition_key => send(partition_key)
                                                 ).update_all(attributes)
      else
        updated_count = self.class.unscoped.where(self.class.primary_key => id).update_all(attributes)
      end
      # wakaru changes end

      attributes.each do |k, v|
        raw_write_attribute(k, v)
      end

      updated_count == 1
    end

    def update_record(attribute_names = @attributes.keys)
      attributes_with_values = arel_attributes_with_values_for_update(attribute_names)
      if attributes_with_values.empty?
        0
      else
        klass = self.class
        column_hash = klass.connection.schema_cache.columns_hash klass.table_name
        db_columns_with_values = attributes_with_values.map { |attr,value|
          real_column = column_hash[attr.name]
          [real_column, value]
        }
        bind_attrs = attributes_with_values.dup
        bind_attrs.keys.each_with_index do |column, i|
          real_column = db_columns_with_values[i].first
          bind_attrs[column] = klass.connection.substitute_at(real_column, i)
        end

        # wakaru changes start
        rel = klass.unscoped.where(klass.arel_table[klass.primary_key].eq(id_was || id))
        if self.class.columns_hash.keys.include?(partition_key)
          rel = rel.where(partition_key => send(partition_key))
        end

        stmt = rel.arel.compile_update(bind_attrs)
        # wakaru changes end

        klass.connection.update stmt, 'SQL', db_columns_with_values
      end
    end

    private

    def relation_for_destroy
      pk         = self.class.primary_key
      column     = self.class.columns_hash[pk]
      substitute = self.class.connection.substitute_at(column, 0)

      relation = self.class.unscoped.where(
        self.class.arel_table[pk].eq(substitute))

      relation.bind_values = [[column, id]]

      # wakaru changes start
      if self.class.columns_hash.keys.include?(partition_key)
        relation = relation.where(partition_key => send(partition_key))
      end
      # wakaru changes end

      relation
    end

    # wakaru changes start
    def partition_key
      "partition_id"
    end
    # wakaru changes end
  end
end
