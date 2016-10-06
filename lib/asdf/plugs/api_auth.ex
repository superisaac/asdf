defmodule Asdf.Plugs.ApiAuth do
  import Ecto.Query
  
  alias Asdf.Repo
  alias Asdf.Cred

  def init(default), do: default

  def call(conn, _options) do
    header_content = Plug.Conn.get_req_header(conn, "authorization")
    case get_auth_user(conn, header_content) do
      nil ->
        stoken = conn.query_params["stoken"]
        if conn |> valid_session_token?(stoken) do
          conn
        else
          conn
          |> send_unauthorized_response("asdfchat")
        end
      user ->
        Asdf.Session.put_current_user(conn, user, "bb")
    end
  end

  defp get_auth_user(_conn, ["Basic " <> encoded_string]) do
    [name, secret] = Base.decode64!(encoded_string) |> String.split(":")

    case Asdf.User.get_user(name) do
      nil -> nil
      user -> 
        case Repo.one(from c in Cred,
                 where:
                 c.user_id == ^user.id and
                 c.name == "default" and
                 c.secret == ^secret
            ) do
          nil -> nil
          _ -> user
        end
    end
  end

  # Handle scenarios where there are no basic auth credentials supplied
  defp get_auth_user(_credentials, _options) do
    nil
  end

  defp valid_session_token?(_conn, nil) do
    false
  end

  defp valid_session_token?(conn, session_token) when session_token != nil do
    Asdf.Session.get_session_token(conn) == session_token
  end

  defp send_unauthorized_response(conn, realm) do
    conn
    |> Plug.Conn.put_resp_header("www-authenticate", "Basic realm=\"#{realm}\"")
    |> Plug.Conn.send_resp(401, "401 Unauthorized\n")
    |> Plug.Conn.halt
  end

end
