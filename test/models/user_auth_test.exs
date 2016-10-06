defmodule Asdf.UserAuthTest do
  use Asdf.ModelCase

  alias Asdf.UserAuth

  @valid_attrs %{avatar_url: "some content", site: "some content", site_userid: "some content", token: "some content", user_name: "some content"}
  @invalid_attrs %{}

  test "changeset with valid attributes" do
    changeset = UserAuth.changeset(%UserAuth{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = UserAuth.changeset(%UserAuth{}, @invalid_attrs)
    refute changeset.valid?
  end
end
