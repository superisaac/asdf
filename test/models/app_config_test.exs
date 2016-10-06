defmodule Asdf.AppConfigTest do
  use Asdf.ModelCase

  alias Asdf.AppConfig

  @valid_attrs %{data: %{}, key: "some content"}
  @invalid_attrs %{}

  test "changeset with valid attributes" do
    changeset = AppConfig.changeset(%AppConfig{}, @valid_attrs)
    assert changeset.valid?
  end

  test "changeset with invalid attributes" do
    changeset = AppConfig.changeset(%AppConfig{}, @invalid_attrs)
    refute changeset.valid?
  end
end
