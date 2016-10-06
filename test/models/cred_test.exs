defmodule Asdf.CredTest do
  use Asdf.ModelCase

  alias Asdf.Cred

  @valid_attrs %{name: "some content", secret: "some content", user_id: 42}
  @invalid_attrs %{}

  test "changeset with valid attributes" do
    changeset = Cred.changeset(%Cred{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = Cred.changeset(%Cred{}, @invalid_attrs)
    refute changeset.valid?
  end
end
