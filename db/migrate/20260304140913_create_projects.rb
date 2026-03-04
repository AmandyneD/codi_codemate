class CreateProjects < ActiveRecord::Migration[8.1]
  def change
    create_table :projects do |t|
      t.string :title
      t.integer :category
      t.integer :level
      t.integer :duration
      t.integer :max_team_members
      t.string :short_description
      t.text :full_description
      t.jsonb :tech_stack
      t.jsonb :team_roles
      t.jsonb :objectives
      t.jsonb :timeline
      t.integer :status

      t.timestamps
    end
  end
end
