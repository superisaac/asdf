defmodule Asdf.Repo.Migrations.CreateRoom do
  use Ecto.Migration

  def change do
    create table(:rooms) do
      add :user_id, :integer
      add :name, :string
      add :is_public, :boolean, default: true, null: false
      add :first_msg_id, :integer, default: 0, null: false
      add :last_msg_id, :integer, default: 0, null: false
      add :type, :integer, default: 0, null: false

      timestamps()
    end
    create index(:rooms, [:user_id, :name], unique: true)
    create index(:rooms, [:user_id, :last_msg_id])
  end
end
