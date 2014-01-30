    create_table :partitions do |t|
      tables = ["images", "images_pages", "pages"]
      shards = 32

      tables.each do |tbl|
        shards.times do |i|
          execute "CREATE TABLE #{tbl}_p#{i} (
              CHECK ( partition_id = #{i} )
              ) INHERITS (#{tbl})"
        end
      end
    end

