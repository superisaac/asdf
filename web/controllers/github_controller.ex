defmodule Asdf.GithubController do
  use Asdf.Web, :controller
  import Ecto.Query
  alias Asdf.UserAuth
  alias Asdf.User
  alias Asdf.Repo

  def auth(conn, _params) do
    cfg = Application.get_env(:asdf, :github_auth)
    
    client_id = cfg |> Keyword.get(:clientid)
    secret = cfg |> Keyword.get(:secret)

    host = get_req_header(conn, "host")|>List.first
    
    
    
    if (client_id != nil and client_id != ""
        and secret != nil and secret != "") do
      auth_url = "https://github.com/login/oauth/authorize?client_id=#{client_id}&redirect_id=#{conn.scheme}://#{host}/auth/github/callback&state=thisistoken"
      redirect conn, external: auth_url
    else
      render conn, "set_github.html"
    end
  end

  def auth_callback(conn, params) do
    #code = params |> Dict.get("code")
    code = params["code"]
    cfg = Application.get_env(:asdf, :github_auth)
    client_id = cfg |> Keyword.get(:clientid)
    secret = cfg |> Keyword.get(:secret)
    body = "client_id=#{client_id}&client_secret=#{secret}&code=#{code}"
    #body = %{"client_id" => client_id, "client_secret" => secret, "code" => code}
    r = HTTPoison.post!("https://github.com/login/oauth/access_token", body, ["Content-Type": "application/x-www-form-urlencoded"])

    q = URI.decode_query(r.body)
    token = q["access_token"]
    r = HTTPoison.get!("https://api.github.com/user?access_token=#{token}")
    u = Poison.decode!(r.body)
    
    userid = u["id"]
    str_userid = "#{userid}"
    
    ua = Repo.one(from u in UserAuth,
                  where: u.site == "github",
                  where: u.site_userid == ^str_userid)

    ua = if ua == nil do
      cset = %UserAuth{
        token: token,
        site: "github",
        site_userid: str_userid,
        user_name: u["login"],
        avatar_url: u["avatar_url"]}
      Repo.insert!(cset)
    else
        cset = UserAuth.changeset(ua,
          %{
            token: token,
            user_name: u["login"],
            avatar_url: u["avatar_url"]})
      Repo.update!(cset)
    end

    ua = ua |> Repo.preload(:user)
    user =
    case ua.user do
      nil -> User.create(ua)
      x -> x
    end

    conn
    |> Asdf.Session.put_current_user(user)
    |> put_flash(:info, "Github logged in")
    |> redirect(to: "/")
  end
end
