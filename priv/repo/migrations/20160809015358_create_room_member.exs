defmodule Asdf.Repo.Migrations.CreateRoomMember do
  use Ecto.Migration

  def change do
    create table(:roommembers) do
      add :user_id, :integer
      add :room_id, :integer
      add :is_admin, :boolean

      timestamps()
    end
    create index(:roommembers, [:user_id, :room_id], unique: true)
  end
end
