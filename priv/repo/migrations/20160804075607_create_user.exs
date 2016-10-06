defmodule Asdf.Repo.Migrations.CreateUser do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :uuid, :string
      add :name, :string
      add :fullname, :string
      add :is_active, :boolean, default: true, null: false
      add :parent_id, :integer, default: 0, null: true
      add :args, :map

      timestamps()
    end
    create index(:users, [:parent_id, :name], unique: true)
    create index(:users, [:parent_id])
    create index(:users, [:uuid])    
  end
end
