defmodule Asdf.Repo.Migrations.CreateUserAuth do
  use Ecto.Migration

  def change do
    create table(:userauths) do
      add :site, :string
      add :token, :string
      add :site_userid, :string, null: true
      add :user_name, :string, null: true
      add :avatar_url, :string, null: true
      add :user_id, references(:users, on_delete: :nothing)

      timestamps()
    end
    create index(:userauths, [:user_id])
    create index(:userauths, [:site, :site_userid], unique: true)
  end
end
