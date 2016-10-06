defmodule Asdf.Repo.Migrations.CreateMsg do
  use Ecto.Migration

  def change do
    create table(:msgs) do
      add :user_id, :integer
      add :room_id, :integer
      add :content, :text
      add :args, :map

      timestamps()
    end

  end
end
