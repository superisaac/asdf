defmodule Asdf.Repo.Migrations.CreateCred do
  use Ecto.Migration

  def change do
    create table(:creds) do
      add :user_id, :integer
      add :name, :string
      add :secret, :string

      timestamps()
    end
    create index(:creds, [:user_id, :name], unique: true)
  end
end
