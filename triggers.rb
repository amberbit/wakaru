# put that to migration
    tables = ["images", "images_pages", "pages"]

    tables.each do |tbl|
      execute "CREATE OR REPLACE FUNCTION #{tbl}_insert_trigger()
               RETURNS TRIGGER AS
               $$
               DECLARE
                  _tablename text;
               BEGIN
                   _tablename := '#{tbl}_p' || NEW.\"partition_id\";

                   EXECUTE 'INSERT INTO ' || quote_ident(_tablename) || ' SELECT ($1).*'
                   USING NEW;
                   RETURN NEW;
               END;
               $$
               LANGUAGE plpgsql;"

      execute "CREATE TRIGGER insert_#{tbl}_trigger
               BEFORE INSERT ON #{tbl}
               FOR EACH ROW EXECUTE PROCEDURE #{tbl}_insert_trigger();"

      execute "CREATE OR REPLACE FUNCTION #{tbl}_delete_master()
               RETURNS trigger
               AS $$
               DECLARE
                   r #{tbl}%rowtype;
               BEGIN
                   DELETE FROM ONLY #{tbl} where id = NEW.id returning * into r;
                   RETURN r;
               END;
               $$
               LANGUAGE plpgsql;"

      execute "create trigger after_insert_#{tbl}_trigger
               after insert on #{tbl}
               for each row
                   execute procedure #{tbl}_delete_master();
               end;"
    end
  end

