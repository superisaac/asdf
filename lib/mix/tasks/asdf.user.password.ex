defmodule Mix.Tasks.Asdf.User.Password do
  use Mix.Task
  import Ecto.Query
  import Asdf.Util
  
  alias Asdf.Repo
  alias Asdf.UserAuth
  alias Asdf.User

  def run(args) do
    Mix.Task.run "app.start", []
    
    {_l_args, no_args, _s_args} = OptionParser.parse args
    
    [user_name, passwd] =
      case no_args do
        [user_name] ->
          [user_name, "?"]
        [user_name, passwd] ->
          [user_name, passwd]
      end

    passwd =
    if passwd == "?" do
      passwd = Asdf.Util.password_get("New password", true)
      case Asdf.Util.password_get("Confirm password", true) do
        ^passwd -> passwd
        _ -> 
          raise ArgumentError, message: "password mismatch"
      end
    else
      passwd
    end

    Repo.transaction fn ->
      encoded_passwd = encode_password(passwd)
      ua = Repo.one(from ua in UserAuth,
                    where: ua.user_name == ^user_name,
                    where: ua.site == "passwd")

      ua = if ua == nil do
        cset = %UserAuth{
          token: encoded_passwd,
          site: "passwd",
          user_name: user_name}
        Repo.insert!(cset)
      else
        cset = UserAuth.changeset(ua,
                                  %{token: encoded_passwd})
        Repo.update!(cset)
      end
      
      ua = ua |> Repo.preload(:user)

      suser =
      if ua.user == nil do
        user = Repo.get_by(Asdf.User, name: user_name)
        if user == nil do
          User.create(ua)
        else
          cset = UserAuth.changeset(ua, %{user_id: user.id})
          Repo.update!(cset)
        end
      end
      IO.puts "created user #{suser.id}"
    end
  end
end
