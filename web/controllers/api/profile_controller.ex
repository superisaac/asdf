defmodule Asdf.Api.ProfileController do
  use Asdf.Web, :controller
  
  def index(conn, _params) do
    user = Asdf.Session.current_user(conn)
    if user do
      ok_json conn, %{:user=> Asdf.User.get_json(user)}
    else
      ok_json conn, %{hello: "anonuser"}
    end
  end
end
