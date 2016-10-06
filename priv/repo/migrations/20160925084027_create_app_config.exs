defmodule Asdf.Repo.Migrations.CreateAppConfig do
  use Ecto.Migration

  def change do
    create table(:appconfigs) do
      add :key, :string
      add :data, :map

      timestamps()
    end
    create index(:appconfigs, [:key], unique: true)
  end
end
